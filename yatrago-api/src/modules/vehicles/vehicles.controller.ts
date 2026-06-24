import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Query,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiConsumes,
  ApiBody,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { VehiclesService } from './vehicles.service';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { imageMulterConfig } from '../../common/utils/multer.config';

@ApiTags('Vehicles')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('vehicles')
export class VehiclesController {
  constructor(private vehiclesService: VehiclesService) {}

  @Post()
  @ApiOperation({ summary: 'Add a new vehicle' })
  create(@CurrentUser() user: any, @Body() dto: CreateVehicleDto) {
    return this.vehiclesService.create(user.id, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all my vehicles' })
  findAll(@CurrentUser() user: any) {
    return this.vehiclesService.findAll(user.id);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get single vehicle with documents' })
  @ApiParam({ name: 'id', description: 'Vehicle ID' })
  findOne(@CurrentUser() user: any, @Param('id') id: string) {
    return this.vehiclesService.findOne(user.id, id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update vehicle details' })
  @ApiParam({ name: 'id', description: 'Vehicle ID' })
  update(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Body() dto: UpdateVehicleDto,
  ) {
    return this.vehiclesService.update(user.id, id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Remove vehicle (soft delete)' })
  @ApiParam({ name: 'id', description: 'Vehicle ID' })
  remove(@CurrentUser() user: any, @Param('id') id: string) {
    return this.vehiclesService.remove(user.id, id);
  }

  @Post(':id/documents')
  @ApiOperation({ summary: 'Upload bluebook or insurance for a vehicle' })
  @ApiParam({ name: 'id', description: 'Vehicle ID' })
  @ApiQuery({ name: 'type', enum: ['bluebook', 'insurance'], required: true })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: { file: { type: 'string', format: 'binary' } },
    },
  })
  @UseInterceptors(FileInterceptor('file', imageMulterConfig))
  uploadDocument(
    @CurrentUser() user: any,
    @Param('id') id: string,
    @Query('type') type: 'bluebook' | 'insurance',
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.vehiclesService.uploadDocument(user.id, id, type, file);
  }
}