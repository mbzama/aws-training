class EventBookingApi {
  static getEvents() {
    const apiEndpoint = process.env.REACT_APP_API_ENDPOINT;
    if (!apiEndpoint) {
      throw new Error('API endpoint not configured');
    }
    const eventsEndpoint = `${apiEndpoint}/events`;

    return fetch(eventsEndpoint, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`API error: ${response.status}`);
        }
        return response.json();
      })
      .then((data) => data.events || [])
      .catch((error) => {
        console.error('Events API error:', error);
        throw error;
      });
  }

  static searchEvents(query) {
    return this.getEvents().then((events) =>
      events.filter(
        (event) =>
          event.name.toLowerCase().includes(query.toLowerCase()) ||
          event.category.toLowerCase().includes(query.toLowerCase()) ||
          event.location.toLowerCase().includes(query.toLowerCase())
      )
    );
  }

  static getEventDetail(eventId) {
    return this.getEvents().then((events) =>
      events.find((e) => e.eventId === eventId)
    );
  }

  static bookTickets(eventId, quantity) {
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const userEmail = user.email || 'demo@example.com';

    // Get API endpoint from env
    const apiEndpoint = process.env.REACT_APP_API_ENDPOINT;
    if (!apiEndpoint) {
      throw new Error('API endpoint not configured. Please set REACT_APP_API_ENDPOINT environment variable.');
    }
    const bookingEndpoint = `${apiEndpoint}/book`;

    return fetch(bookingEndpoint, {
      method: 'POST',
      mode: 'cors',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer demo-token-for-testing'
      },
      body: JSON.stringify({
        eventId,
        quantity: parseInt(quantity),
        userEmail,
      }),
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`API error: ${response.status} ${response.statusText}`);
        }
        return response.json();
      })
      .then((data) => {
        if (data.error) {
          throw new Error(data.error);
        }
        return {
          bookingId: data.bookingId,
          eventId: eventId,
          quantity: parseInt(quantity),
          totalPrice: data.totalPrice,
          status: data.status || 'CONFIRMED',
        };
      })
      .catch((error) => {
        console.error('Booking API error:', error);
        throw error;
      });
  }

  static getBookingHistory() {
    const apiEndpoint = process.env.REACT_APP_API_ENDPOINT;
    if (!apiEndpoint) {
      throw new Error('API endpoint not configured');
    }
    const historyEndpoint = `${apiEndpoint}/history`;

    return fetch(historyEndpoint, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`API error: ${response.status}`);
        }
        return response.json();
      })
      .then((data) => {
        const bookings = data.bookings || [];
        const totalBookings = bookings.length;
        const totalSpent = bookings.reduce((sum, b) => sum + parseFloat(b.totalPrice || 0), 0);
        const confirmedBookings = bookings.filter(b => b.status === 'CONFIRMED').length;
        const processingBookings = bookings.filter(b => b.status === 'PROCESSING').length;

        return {
          bookings,
          statistics: {
            totalBookings,
            totalSpent: parseFloat(totalSpent.toFixed(2)),
            confirmedBookings,
            processingBookings
          }
        };
      })
      .catch((error) => {
        console.error('Booking history API error:', error);
        throw error;
      });
  }
}

export default EventBookingApi;
