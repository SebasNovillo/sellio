import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import type { HealthResponse } from '@sellio/types';

@ApiTags('Health')
@Controller('health')
export class HealthController {
  @Get()
  @ApiOkResponse({
    description: 'The API process is running. External services are not checked.',
    schema: {
      type: 'object',
      required: ['status', 'service'],
      properties: { status: { type: 'string', enum: ['ok'] }, service: { type: 'string', enum: ['sellio-api'] } },
    },
  })
  getHealth(): HealthResponse {
    return { status: 'ok', service: 'sellio-api' };
  }
}
