import { Test, TestingModule } from '@nestjs/testing';
import { InvoicesController } from './invoices/invoices.controller';
import { InvoicesService } from './invoices/invoices.service';

describe('InvoicesController', () => {
  let controller: InvoicesController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [InvoicesController],
      providers: [InvoicesService],
    }).compile();
    controller = module.get<InvoicesController>(InvoicesController);
  });

  it('should return all invoices', () => {
    const invoices = controller.findAll();
    expect(invoices).toHaveLength(3);
  });

  it('should return a single invoice', () => {
    const invoice = controller.findOne(1);
    expect(invoice.id).toBe(1);
    expect(invoice.invoiceNumber).toBe('INV-0001');
    expect(invoice.customerName).toBe('Acme Corp');
    expect(invoice.status).toBe('paid');
  });

  it('should create an invoice', () => {
    const invoice = controller.create({
      customerId: 104,
      customerName: 'Umbrella Corp',
      status: 'draft',
      items: [{ description: 'API Integration', quantity: 1, unitPrice: 750.0, total: 750.0 }],
      subtotal: 750.0,
      tax: 75.0,
      total: 825.0,
      dueDate: '2025-04-30',
    });
    expect(invoice.id).toBe(4);
    expect(invoice.invoiceNumber).toBe('INV-0004');
    expect(invoice.customerName).toBe('Umbrella Corp');
  });

  it('should update an invoice status', () => {
    const invoice = controller.update(2, { status: 'paid' });
    expect(invoice.status).toBe('paid');
  });

  it('should throw when invoice not found', () => {
    expect(() => controller.findOne(999)).toThrow();
  });
});
