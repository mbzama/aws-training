// Mock events data - in production, would be stored in EventsTable
const MOCK_EVENTS = [
  {
    eventId: 'event-001',
    name: 'Summer Music Festival 2026',
    description: 'Three-day electronic music festival featuring world-renowned DJs and live performers',
    category: 'Music',
    date: '2026-07-15',
    endDate: '2026-07-17',
    location: 'Central Park, New York',
    capacity: 5000,
    ticketPrice: 99.99,
    ticketsSold: 3200,
    imageUrl: 'https://example.com/images/music-festival.jpg',
    status: 'ACTIVE',
    createdAt: '2026-01-01T00:00:00Z',
  },
  {
    eventId: 'event-002',
    name: 'Tech Conference 2026',
    description: 'Annual technology conference with keynote speeches from industry leaders',
    category: 'Technology',
    date: '2026-08-20',
    endDate: '2026-08-22',
    location: 'San Francisco Convention Center',
    capacity: 2000,
    ticketPrice: 299.99,
    ticketsSold: 1500,
    imageUrl: 'https://example.com/images/tech-conf.jpg',
    status: 'ACTIVE',
    createdAt: '2026-01-05T00:00:00Z',
  },
  {
    eventId: 'event-003',
    name: 'International Food Carnival',
    description: 'Global food festival showcasing cuisines from 50+ countries',
    category: 'Food',
    date: '2026-09-10',
    endDate: '2026-09-12',
    location: 'Waterfront Park, Miami',
    capacity: 3000,
    ticketPrice: 49.99,
    ticketsSold: 2100,
    imageUrl: 'https://example.com/images/food-carnival.jpg',
    status: 'ACTIVE',
    createdAt: '2026-01-10T00:00:00Z',
  },
  {
    eventId: 'event-004',
    name: 'Championship Basketball Tournament',
    description: 'Elite basketball competition featuring 16 teams competing for the title',
    category: 'Sports',
    date: '2026-10-01',
    endDate: '2026-10-15',
    location: 'Madison Square Garden, New York',
    capacity: 20000,
    ticketPrice: 149.99,
    ticketsSold: 15000,
    imageUrl: 'https://example.com/images/basketball.jpg',
    status: 'ACTIVE',
    createdAt: '2026-01-15T00:00:00Z',
  },
];

const getEvent = async (eventId) => {
  const event = MOCK_EVENTS.find(e => e.eventId === eventId);
  return event || null;
};

const getAllEvents = async () => {
  return MOCK_EVENTS;
};

const searchEvents = async (query) => {
  const lowerQuery = query.toLowerCase();
  return MOCK_EVENTS.filter(
    event =>
      event.name.toLowerCase().includes(lowerQuery) ||
      event.description.toLowerCase().includes(lowerQuery) ||
      event.category.toLowerCase().includes(lowerQuery) ||
      event.location.toLowerCase().includes(lowerQuery)
  );
};

const isEventAvailable = async (eventId, quantity = 1) => {
  const event = await getEvent(eventId);
  if (!event) return false;
  return event.capacity - event.ticketsSold >= quantity;
};

module.exports = {
  getEvent,
  getAllEvents,
  searchEvents,
  isEventAvailable,
  MOCK_EVENTS,
};
