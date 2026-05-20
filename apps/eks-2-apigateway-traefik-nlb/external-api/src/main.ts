import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('external');
  await app.listen(3000);
  console.log('Mock External API running on http://localhost:3000/external');
}
bootstrap();
