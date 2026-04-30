import { Injectable, NotFoundException } from '@nestjs/common';

export type InvoiceStatus = 'draft' | 'sent' | 'paid' | 'overdue' | 'cancelled';

export interface InvoiceItem {
  description: string;
  quantity: number;
  unitPrice: number;
  total: number;
}

export interface Invoice {
  id: number;
  invoiceNumber: string;
  customerId: number;
  customerName: string;
  status: InvoiceStatus;
  items: InvoiceItem[];
  subtotal: number;
  tax: number;
  total: number;
  dueDate: string;
  createdAt: string;
}

@Injectable()
export class InvoicesService {
  private invoices: Invoice[] = [
    {
      id: 1,
      invoiceNumber: 'INV-0001',
      customerId: 101,
      customerName: 'Acme Corp',
      status: 'paid',
      items: [
        { description: 'Consulting Services', quantity: 10, unitPrice: 150.0, total: 1500.0 },
        { description: 'Software License', quantity: 1, unitPrice: 299.99, total: 299.99 },
      ],
      subtotal: 1799.99,
      tax: 180.0,
      total: 1979.99,
      dueDate: '2025-02-28',
      createdAt: '2025-01-31',
    },
    {
      id: 2,
      invoiceNumber: 'INV-0002',
      customerId: 102,
      customerName: 'Globex Inc',
      status: 'sent',
      items: [
        { description: 'Cloud Hosting (Monthly)', quantity: 3, unitPrice: 200.0, total: 600.0 },
      ],
      subtotal: 600.0,
      tax: 60.0,
      total: 660.0,
      dueDate: '2025-03-15',
      createdAt: '2025-02-14',
    },
    {
      id: 3,
      invoiceNumber: 'INV-0003',
      customerId: 103,
      customerName: 'Initech LLC',
      status: 'overdue',
      items: [
        { description: 'Support Package', quantity: 1, unitPrice: 499.0, total: 499.0 },
        { description: 'Training Hours', quantity: 5, unitPrice: 120.0, total: 600.0 },
      ],
      subtotal: 1099.0,
      tax: 109.9,
      total: 1208.9,
      dueDate: '2025-01-10',
      createdAt: '2024-12-10',
    },
  ];

  private nextId = 4;

  findAll(): Invoice[] {
    return this.invoices;
  }

  findOne(id: number): Invoice {
    const invoice = this.invoices.find((i) => i.id === id);
    if (!invoice) throw new NotFoundException(`Invoice #${id} not found`);
    return invoice;
  }

  create(dto: Omit<Invoice, 'id' | 'invoiceNumber' | 'createdAt'>): Invoice {
    const invoice: Invoice = {
      id: this.nextId,
      invoiceNumber: `INV-${String(this.nextId).padStart(4, '0')}`,
      createdAt: new Date().toISOString().split('T')[0],
      ...dto,
    };
    this.invoices.push(invoice);
    this.nextId++;
    return invoice;
  }

  update(id: number, dto: Partial<Omit<Invoice, 'id' | 'invoiceNumber' | 'createdAt'>>): Invoice {
    const invoice = this.findOne(id);
    Object.assign(invoice, dto);
    return invoice;
  }

  remove(id: number): void {
    const index = this.invoices.findIndex((i) => i.id === id);
    if (index === -1) throw new NotFoundException(`Invoice #${id} not found`);
    this.invoices.splice(index, 1);
  }
}
