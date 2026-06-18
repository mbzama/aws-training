import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import EventBookingApi from '../services/EventBookingApi';
import './EventsPage.css';

function EventsPage({ user }) {
  const [events, setEvents] = useState([]);
  const [filteredEvents, setFilteredEvents] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedEvent, setSelectedEvent] = useState(null);
  const [quantity, setQuantity] = useState(1);
  const [booking, setBooking] = useState(null);
  const [bookingError, setBookingError] = useState('');
  const [bookingLoading, setBookingLoading] = useState(false);

  useEffect(() => {
    fetchEvents();
  }, []);

  const fetchEvents = async () => {
    setLoading(true);
    setError('');

    try {
      const data = await EventBookingApi.getEvents();
      setEvents(data);
      setFilteredEvents(data);
    } catch (err) {
      setError('Failed to load events. Please try again.');
      console.error('Error fetching events:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async (e) => {
    e.preventDefault();
    setSearchQuery(e.target.value);

    if (!e.target.value.trim()) {
      setFilteredEvents(events);
      return;
    }

    try {
      const results = await EventBookingApi.searchEvents(e.target.value);
      setFilteredEvents(results);
    } catch (err) {
      console.error('Error searching events:', err);
      setError('Search failed. Please try again.');
    }
  };

  const handleBookEvent = (event) => {
    setSelectedEvent(event);
    setQuantity(1);
    setBookingError('');
    setBooking(null);
  };

  const handleConfirmBooking = async () => {
    setBookingLoading(true);
    setBookingError('');

    try {
      const bookingData = await EventBookingApi.bookTickets(selectedEvent.eventId, quantity);

      // Store booking in localStorage for booking history
      const bookings = JSON.parse(localStorage.getItem('bookings') || '[]');
      const fullBooking = {
        ...bookingData,
        userId: user?.email || 'demo@example.com',
        email: 'lreddy1@evoketechnologies.com',
        createdAt: new Date().toISOString(),
        eventLocation: selectedEvent.location
      };
      bookings.push(fullBooking);
      localStorage.setItem('bookings', JSON.stringify(bookings));

      setBooking(bookingData);
    } catch (err) {
      setBookingError(err.response?.data?.error?.message || 'Booking failed. Please try again.');
      console.error('Error booking tickets:', err);
    } finally {
      setBookingLoading(false);
    }
  };

  const closeModal = () => {
    setSelectedEvent(null);
    setBooking(null);
    setBookingError('');
  };

  if (loading) {
    return <div className="loading">Loading events...</div>;
  }

  return (
    <div className="events-page">
      <div className="container">
        <div className="page-header">
          <h2>Available Events</h2>
          <Link to="/history" className="btn btn-history">
            📋 View Booking History
          </Link>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        <div className="search-box">
          <input
            type="text"
            placeholder="🔍 Search events by name, category, or location..."
            value={searchQuery}
            onChange={handleSearch}
            className="search-input"
          />
        </div>

        {filteredEvents.length === 0 ? (
          <div className="no-results">No events found. Try a different search.</div>
        ) : (
          <div className="events-grid">
            {filteredEvents.map((event) => (
              <div key={event.eventId} className="event-card">
                <div className="event-header">
                  <h3>{event.name}</h3>
                  <span className="category-badge">{event.category}</span>
                </div>

                <p className="event-description">{event.description}</p>

                <div className="event-details">
                  <div className="detail-item">
                    <span className="label">📍 Location:</span>
                    <span className="value">{event.location}</span>
                  </div>
                  <div className="detail-item">
                    <span className="label">📅 Date:</span>
                    <span className="value">{new Date(event.date).toLocaleDateString()}</span>
                  </div>
                  <div className="detail-item">
                    <span className="label">💰 Price:</span>
                    <span className="value price">${parseFloat(event.ticketPrice).toFixed(2)}</span>
                  </div>
                  <div className="detail-item">
                    <span className="label">🎫 Available:</span>
                    <span className="value">
                      {event.capacity - event.ticketsSold} of {event.capacity}
                    </span>
                  </div>
                </div>

                <div className="progress-bar">
                  <div
                    className="progress-fill"
                    style={{
                      width: `${((event.ticketsSold / event.capacity) * 100).toFixed(0)}%`,
                    }}
                  ></div>
                </div>

                <button
                  className="btn btn-book"
                  onClick={() => handleBookEvent(event)}
                  disabled={event.capacity - event.ticketsSold === 0}
                >
                  {event.capacity - event.ticketsSold === 0 ? 'Sold Out' : 'Book Tickets'}
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {selectedEvent && (
        <div className="modal-overlay" onClick={closeModal}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <button className="btn-close" onClick={closeModal}>
              ✕
            </button>

            {booking ? (
              <div className="booking-success">
                <h3>✅ Booking Confirmed!</h3>
                <div className="booking-details">
                  <div className="detail">
                    <label>Booking ID:</label>
                    <span>{booking.bookingId}</span>
                  </div>
                  <div className="detail">
                    <label>Event:</label>
                    <span>{booking.eventName}</span>
                  </div>
                  <div className="detail">
                    <label>Tickets:</label>
                    <span>{booking.quantity} × ${parseFloat(selectedEvent.ticketPrice).toFixed(2)}</span>
                  </div>
                  <div className="detail">
                    <label>Total Price:</label>
                    <span className="total-price">${parseFloat(booking.totalPrice).toFixed(2)}</span>
                  </div>
                  <div className="detail">
                    <label>Status:</label>
                    <span className="status-badge">{booking.status}</span>
                  </div>
                </div>
                <p className="ticket-message">
                  Your ticket will be generated shortly. Check your booking history to download it.
                </p>
                <button className="btn" onClick={closeModal}>
                  Continue Shopping
                </button>
              </div>
            ) : (
              <div className="booking-form">
                <h3>Book {selectedEvent.name}</h3>

                {bookingError && <div className="alert alert-error">{bookingError}</div>}

                <div className="event-info">
                  <p>
                    <strong>Date:</strong> {new Date(selectedEvent.date).toLocaleDateString()}
                  </p>
                  <p>
                    <strong>Location:</strong> {selectedEvent.location}
                  </p>
                  <p>
                    <strong>Price per ticket:</strong> {parseFloat(selectedEvent.ticketPrice).toFixed(2)}
                  </p>
                </div>

                <div className="form-group">
                  <label htmlFor="quantity">Number of Tickets:</label>
                  <select
                    id="quantity"
                    value={quantity}
                    onChange={(e) => setQuantity(parseInt(e.target.value))}
                  >
                    {Array.from({ length: 10 }, (_, i) => i + 1).map((num) => (
                      <option key={num} value={num}>
                        {num} ticket{num > 1 ? 's' : ''}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="price-summary">
                  <p>
                    <strong>Total:</strong>
                  </p>
                  <p className="total-amount">
                    ${(parseFloat(selectedEvent.ticketPrice) * quantity).toFixed(2)}
                  </p>
                </div>

                <div className="modal-buttons">
                  <button className="btn btn-secondary" onClick={closeModal}>
                    Cancel
                  </button>
                  <button
                    className="btn"
                    onClick={handleConfirmBooking}
                    disabled={bookingLoading}
                  >
                    {bookingLoading ? 'Processing...' : 'Confirm Booking'}
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

export default EventsPage;
