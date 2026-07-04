import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ReportsService } from './reports.service';
import { CreateReportDto } from './dto/create-report.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Reports')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('reports')
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  @Post()
  @ApiOperation({ summary: 'Report a user (optionally tied to a booking)' })
  create(@CurrentUser() user: any, @Body() dto: CreateReportDto) {
    return this.reportsService.create(user.id, dto);
  }

  @Get('mine')
  @ApiOperation({ summary: 'List reports I have filed' })
  findMine(@CurrentUser() user: any) {
    return this.reportsService.findMine(user.id);
  }
}
