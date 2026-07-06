import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { SearchService } from './search.service';
import { SearchTripsDto } from './search.dto';

@ApiTags('Search')
@Controller('search')
export class SearchController {
  constructor(private searchService: SearchService) {}

  @Get()
  @ApiOperation({
    summary: 'Search available rides',
    description:
      'Search by origin, destination, date and seats. No auth required — passengers can browse before logging in.',
  })
  search(@Query() dto: SearchTripsDto) {
    return this.searchService.searchTrips(dto);
  }
}
