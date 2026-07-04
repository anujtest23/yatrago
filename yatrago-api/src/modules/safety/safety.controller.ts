import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SafetyService } from './safety.service';
import { CreateSosDto } from './dto/create-sos.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Safety')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('sos')
export class SafetyController {
  constructor(private safetyService: SafetyService) {}

  @Post()
  @ApiOperation({
    summary: 'Trigger an SOS alert — notifies emergency contacts by SMS',
  })
  createSos(@CurrentUser() user: any, @Body() dto: CreateSosDto) {
    return this.safetyService.createSos(user.id, dto);
  }

  @Get('mine')
  @ApiOperation({ summary: 'List own SOS alerts' })
  getMyAlerts(@CurrentUser() user: any) {
    return this.safetyService.getMyAlerts(user.id);
  }
}
