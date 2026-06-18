const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

const BOOKING_STATUS = {
  PENDING: 'PENDING',
  PROCESSING: 'PROCESSING',
  CONFIRMED: 'CONFIRMED',
  FAILED: 'FAILED',
  CANCELLED: 'CANCELLED',
};

const generateBookingId = () => {
  return `BOOK-${Date.now()}-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
};

const createBooking = (userId, eventId, quantity, eventName, eventDate) => {
  const bookingId = generateBookingId();
  const now = new Date().toISOString();

  return {
    userId,
    bookingId,
    eventId,
    eventName,
    eventDate,
    quantity,
    status: BOOKING_STATUS.PENDING,
    totalPrice: 0, // Will be calculated based on event details
    ticketUrl: null,
    createdAt: now,
    updatedAt: now,
  };
};

const updateBookingStatus = (booking, newStatus) => {
  return {
    ...booking,
    status: newStatus,
    updatedAt: new Date().toISOString(),
  };
};

const formatBookingForResponse = (booking) => {
  return {
    bookingId: booking.bookingId,
    eventId: booking.eventId,
    eventName: booking.eventName,
    eventDate: booking.eventDate,
    quantity: booking.quantity,
    status: booking.status,
    totalPrice: booking.totalPrice,
    ticketUrl: booking.ticketUrl,
    createdAt: booking.createdAt,
    updatedAt: booking.updatedAt,
  };
};

module.exports = {
  BOOKING_STATUS,
  generateBookingId,
  createBooking,
  updateBookingStatus,
  formatBookingForResponse,
};
