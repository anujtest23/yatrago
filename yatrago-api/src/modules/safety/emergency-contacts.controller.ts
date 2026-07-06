import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiParam,
} from '@nestjs/swagger';
import { SafetyService } from './safety.service';
import { CreateEmergencyContactDto } from './dto/create-emergency-contact.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Safety')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users/me/emergency-contacts')
export class EmergencyContactsController {
  constructor(private safetyService: SafetyService) {}

  @Get()
  @ApiOperation({ summary: 'List own emergency contacts' })
  getContacts(@CurrentUser() user: any) {
    return this.safetyService.getEmergencyContacts(user.id);
  }

  @Post()
  @ApiOperation({ summary: 'Add an emergency contact (max 3)' })
  addContact(@CurrentUser() user: any, @Body() dto: CreateEmergencyContactDto) {
    return this.safetyService.addEmergencyContact(user.id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Remove an emergency contact' })
  @ApiParam({ name: 'id', description: 'Emergency Contact ID' })
  removeContact(@CurrentUser() user: any, @Param('id') id: string) {
    return this.safetyService.removeEmergencyContact(user.id, id);
  }
}
