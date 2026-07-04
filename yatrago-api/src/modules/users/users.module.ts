import { Module } from '@nestjs/common';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { AccountDeletionJob } from './account-deletion.job';

@Module({
  controllers: [UsersController],
  providers: [UsersService, AccountDeletionJob],
  exports: [UsersService],
})
export class UsersModule {}
