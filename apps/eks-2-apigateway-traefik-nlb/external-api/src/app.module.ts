import { Module } from '@nestjs/common';
import { InvoicesModule } from './invoices/invoices.module';

@Module({
  imports: [InvoicesModule],
})
export class AppModule {}
