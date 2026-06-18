import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import EventBookingApi from '../services/EventBookingApi';
import './BookingHistoryPage.css';

function BookingHistoryPage({ user }) {
  const [bookings, setBookings] = useState([]);
  const [statistics, setStatistics] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedBooking, setSelectedBooking] = useState(null);

  useEffect(() => {
    fetchBookingHistory();

    // Refresh bookings every time the page is visited
    window.addEventListener('focus', fetchBookingHistory);
    return () => window.removeEventListener('focus', fetchBookingHistory);
  }, []);

  const fetchBookingHistory = async () => {
    setLoading(true);
    setError('');

    try {
      const data = await EventBookingApi.getBookingHistory();
      setBookings(data.bookings || []);
      setStatistics(data.statistics || {});
    } catch (err) {
      setError('Failed to load booking history. Please try again.');
      console.error('Error fetching booking history:', err);
    } finally {
      setLoading(false);
    }
  };

  const downloadTicket = (booking) => {
    if (booking.ticketUrl) {
      const link = document.createElement('a');
      link.href = booking.ticketUrl;
      link.download = `ticket-${booking.bookingId}.pdf`;
      link.click();
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'CONFIRMED':
        return '#48bb78';
      case 'PROCESSING':
        return '#ed8936';
      case 'PENDING':
        return '#ecc94b';
      case 'FAILED':
        return '#f56565';
      default:
        return '#718096';
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'CONFIRMED':
        return '✅';
      case 'PROCESSING':
        return '⏳';
      case 'PENDING':
        return '⏱️';
      case 'FAILED':
        return '❌';
      default:
        return '❓';
    }
  };

  if (loading) {
    return <div className="loading">Loading booking history...</div>;
  }

  return (
    <div className="booking-history-page">
      <div className="container">
        <div className="page-header">
          <h2>My Bookings</h2>
          <div className="header-actions">
            <button className="btn btn-refresh" onClick={fetchBookingHistory}>
              🔄 Refresh
            </button>
            <Link to="/events" className="btn btn-events">
              🎫 Browse Events
            </Link>
          </div>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        {statistics && (
          <div className="statistics">
            <div className="stat-card">
              <div className="stat-value">{statistics.totalBookings}</div>
              <div className="stat-label">Total Bookings</div>
            </div>
            <div className="stat-card">
              <div className="stat-value">{statistics.confirmedBookings}</div>
              <div className="stat-label">Confirmed</div>
            </div>
            <div className="stat-card">
              <div className="stat-value">{statistics.processingBookings}</div>
              <div className="stat-label">Processing</div>
            </div>
            <div className="stat-card">
              <div className="stat-value">${parseFloat(statistics.totalSpent).toFixed(2)}</div>
              <div className="stat-label">Total Spent</div>
            </div>
          </div>
        )}

        {bookings.length === 0 ? (
          <div className="empty-state">
            <div className="empty-icon">📋</div>
            <h3>No bookings yet</h3>
            <p>You haven't booked any tickets yet.</p>
            <Link to="/events" className="btn">
              Browse Events
            </Link>
          </div>
        ) : (
          <div className="bookings-list">
            {bookings.map((booking) => (
              <div key={booking.bookingId} className="booking-card">
                <div className="booking-header">
                  <div className="booking-title">
                    <h3>{booking.eventName}</h3>
                    <span className="booking-id">ID: {booking.bookingId}</span>
                  </div>
                  <div className="status-indicator" style={{ backgroundColor: getStatusColor(booking.status) }}>
                    <span>{getStatusIcon(booking.status)} {booking.status}</span>
                  </div>
                </div>

                <div className="booking-details">
                  <div className="detail">
                    <span className="label">📅 Event Date:</span>
                    <span className="value">{new Date(booking.eventDate).toLocaleDateString()}</span>
                  </div>
                  <div className="detail">
                    <span className="label">🎫 Tickets:</span>
                    <span className="value">{booking.quantity}</span>
                  </div>
                  <div className="detail">
                    <span className="label">💰 Total Price:</span>
                    <span className="value price">${parseFloat(booking.totalPrice).toFixed(2)}</span>
                  </div>
                  <div className="detail">
                    <span className="label">📝 Booked On:</span>
                    <span className="value">{new Date(booking.createdAt).toLocaleDateString()}</span>
                  </div>
                </div>

                <div className="booking-actions">
                  <button
                    className="btn-detail"
                    onClick={() => setSelectedBooking(booking)}
                  >
                    View Details
                  </button>
                  {booking.status === 'CONFIRMED' && booking.ticketUrl && (
                    <button
                      className="btn-download"
                      onClick={() => downloadTicket(booking)}
                    >
                      📥 Download Ticket
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {selectedBooking && (
        <div className="modal-overlay" onClick={() => setSelectedBooking(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <button className="btn-close" onClick={() => setSelectedBooking(null)}>
              ✕
            </button>

            <div className="booking-detail-view">
              <h3>{selectedBooking.eventName}</h3>

              <div className="detail-grid">
                <div className="detail-box">
                  <label>Booking ID</label>
                  <p className="booking-id-large">{selectedBooking.bookingId}</p>
                </div>

                <div className="detail-box">
                  <label>Status</label>
                  <p
                    className="status-text"
                    style={{ color: getStatusColor(selectedBooking.status) }}
                  >
                    {getStatusIcon(selectedBooking.status)} {selectedBooking.status}
                  </p>
                </div>

                <div className="detail-box">
                  <label>Event Date</label>
                  <p>{new Date(selectedBooking.eventDate).toLocaleDateString()}</p>
                </div>

                <div className="detail-box">
                  <label>Number of Tickets</label>
                  <p>{selectedBooking.quantity}</p>
                </div>

                <div className="detail-box">
                  <label>Total Price</label>
                  <p className="price-large">${parseFloat(selectedBooking.totalPrice).toFixed(2)}</p>
                </div>

                <div className="detail-box">
                  <label>Booked On</label>
                  <p>{new Date(selectedBooking.createdAt).toLocaleDateString()}</p>
                </div>

                <div className="detail-box">
                  <label>Last Updated</label>
                  <p>{new Date(selectedBooking.updatedAt).toLocaleDateString()}</p>
                </div>

                {selectedBooking.ticketUrl && (
                  <div className="detail-box">
                    <label>Ticket URL</label>
                    <p className="ticket-url-text">{selectedBooking.ticketUrl}</p>
                  </div>
                )}
              </div>

              <div className="detail-actions">
                <button
                  className="btn btn-secondary"
                  onClick={() => setSelectedBooking(null)}
                >
                  Close
                </button>
                {selectedBooking.status === 'CONFIRMED' && selectedBooking.ticketUrl && (
                  <button
                    className="btn"
                    onClick={() => {
                      downloadTicket(selectedBooking);
                      setSelectedBooking(null);
                    }}
                  >
                    📥 Download Ticket
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default BookingHistoryPage;
