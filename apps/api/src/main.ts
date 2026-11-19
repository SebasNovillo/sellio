import 'reflect-metadata';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);
  app.enableShutdownHooks();
  app.setGlobalPrefix('api');

  if (config.get<boolean>('API_DOCS_ENABLED')) {
    const options = new DocumentBuilder()
      .setTitle('Sellio API')
      .setDescription('Sellio REST API foundation')
      .setVersion('0.0.0')
      .build();
    SwaggerModule.setup('api/docs', app, SwaggerModule.createDocument(app, options));
  }

  await app.listen(config.getOrThrow<number>('PORT'));
}

bootstrap().catch((error: unknown) => {
  Logger.error(error, 'Bootstrap');
  process.exitCode = 1;
});
