import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  ParseIntPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { InvoicesService, Invoice } from './invoices.service';

@Controller('invoices')
export class InvoicesController {
  constructor(private readonly invoicesService: InvoicesService) {}

  @Get()
  findAll(): Invoice[] {
    return this.invoicesService.findAll();
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number): Invoice {
    return this.invoicesService.findOne(id);
  }

  @Post()
  create(@Body() body: Omit<Invoice, 'id' | 'invoiceNumber' | 'createdAt'>): Invoice {
    return this.invoicesService.create(body);
  }

  @Put(':id')
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: Partial<Omit<Invoice, 'id' | 'invoiceNumber' | 'createdAt'>>,
  ): Invoice {
    return this.invoicesService.update(id, body);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@Param('id', ParseIntPipe) id: number): void {
    this.invoicesService.remove(id);
  }
}
