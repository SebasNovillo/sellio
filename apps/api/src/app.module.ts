import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { runtimeConfigurationOptions } from './config/runtime-environment.js';
import { HealthModule } from './health/health.module.js';
import { DatabaseModule } from './infrastructure/database/database.module.js';

@Module({
  imports: [
    ConfigModule.forRoot(runtimeConfigurationOptions()),
    HealthModule,
    DatabaseModule,
  ],
})
export class AppModule {}
