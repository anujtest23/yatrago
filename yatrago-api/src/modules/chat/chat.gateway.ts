import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Logger, Inject, forwardRef } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { appConfig } from '../../config/app.config';
import { ChatService } from './chat.service';

// A socket carries its authenticated user id once the handshake is verified.
interface AuthedSocket extends Socket {
  userId?: string;
}

function bookingRoom(bookingId: string): string {
  return `booking:${bookingId}`;
}
function userRoom(userId: string): string {
  return `user:${userId}`;
}

@WebSocketGateway({
  namespace: '/chat',
  // Mobile apps send no Origin, so any is fine here; JWT is the real gate.
  cors: { origin: true, credentials: true },
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger('ChatGateway');

  @WebSocketServer()
  server: Server;

  constructor(
    private jwt: JwtService,
    @Inject(forwardRef(() => ChatService))
    private chat: ChatService,
  ) {}

  // ── Connection: authenticate the handshake or disconnect ─────
  handleConnection(client: AuthedSocket) {
    try {
      const token =
        (client.handshake.auth?.token as string) ||
        this.bearerFrom(client.handshake.headers.authorization);
      if (!token) throw new Error('missing token');

      const payload = this.jwt.verify(token, {
        issuer: appConfig.jwtIssuer,
        audience: appConfig.jwtAudience,
      }) as { sub: string; type: string };

      // Only ACCESS tokens grant socket access — never a refresh token.
      if (payload.type !== 'access') throw new Error('wrong token type');

      client.userId = payload.sub;
      // Personal room drives cross-conversation nudges (unread badge).
      void client.join(userRoom(payload.sub));
    } catch {
      // Never leak why — just refuse the socket.
      client.disconnect(true);
    }
  }

  handleDisconnect(_client: AuthedSocket) {
    // Socket.IO cleans up room membership automatically.
  }

  private bearerFrom(header?: string): string | undefined {
    if (!header) return undefined;
    const [scheme, value] = header.split(' ');
    return scheme === 'Bearer' ? value : undefined;
  }

  // ── Join a conversation room ─────────────────────────────────
  // Membership is authorized server-side every time: a client cannot listen
  // to a booking room it is not a participant of.
  @SubscribeMessage('join')
  async onJoin(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { bookingId: string },
  ) {
    if (!client.userId || !body?.bookingId) return { ok: false };
    try {
      await this.chat.resolveAccess(client.userId, body.bookingId);
      await client.join(bookingRoom(body.bookingId));
      return { ok: true };
    } catch {
      return { ok: false };
    }
  }

  @SubscribeMessage('leave')
  async onLeave(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { bookingId: string },
  ) {
    if (body?.bookingId) await client.leave(bookingRoom(body.bookingId));
    return { ok: true };
  }

  // ── Send via socket (also validated + persisted server-side) ─
  @SubscribeMessage('message')
  async onMessage(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { bookingId: string; content: string },
  ) {
    if (!client.userId) return { ok: false, error: 'unauthenticated' };
    try {
      const message = await this.chat.sendMessage(
        client.userId,
        body.bookingId,
        body.content,
      );
      // broadcastMessage (called inside sendMessage) already fanned out.
      return { ok: true, message };
    } catch (err) {
      return { ok: false, error: (err as Error).message };
    }
  }

  // ── Mark read via socket ─────────────────────────────────────
  @SubscribeMessage('read')
  async onRead(
    @ConnectedSocket() client: AuthedSocket,
    @MessageBody() body: { bookingId: string },
  ) {
    if (!client.userId || !body?.bookingId) return { ok: false };
    try {
      await this.chat.markRead(client.userId, body.bookingId);
      return { ok: true };
    } catch {
      return { ok: false };
    }
  }

  // ── Server-side broadcast helpers (called by ChatService) ────
  broadcastMessage(bookingId: string, message: unknown, receiverId: string) {
    if (!this.server) return;
    this.server.to(bookingRoom(bookingId)).emit('message', message);
    // Nudge the receiver's personal room so an off-screen unread badge ticks.
    this.server
      .to(userRoom(receiverId))
      .emit('conversation_update', { bookingId });
  }

  broadcastRead(bookingId: string, readerId: string, otherUserId: string) {
    if (!this.server) return;
    this.server
      .to(bookingRoom(bookingId))
      .emit('read', { bookingId, readerId });
    this.server
      .to(userRoom(otherUserId))
      .emit('conversation_update', { bookingId });
  }

  broadcastConversationOpened(bookingId: string, userIds: string[]) {
    if (!this.server) return;
    for (const uid of userIds) {
      this.server
        .to(userRoom(uid))
        .emit('conversation_opened', { bookingId });
    }
  }
}
