import React, { useEffect, useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import CognitoAuthService from './services/CognitoAuthService';
import LoginPage from './pages/LoginPage';
import EventsPage from './pages/EventsPage';
import BookingHistoryPage from './pages/BookingHistoryPage';
import './App.css';

function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  // Clear localStorage on first load to prevent auto-login from old sessions
  localStorage.clear();

  useEffect(() => {
    checkUser();
  }, []);

  const checkUser = async () => {
    try {
      const currentUser = await CognitoAuthService.getCurrentUser();
      setUser(currentUser);
    } catch (error) {
      console.error('Error checking user:', error);
      setUser(null);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    CognitoAuthService.signOut();
    setUser(null);
  };

  if (loading) {
    return <div className="loading">Loading...</div>;
  }

  return (
    <Router>
      <div className="app">
        <header className="header">
          <div className="container">
            <h1>🎭 Event Ticket Booking Platform</h1>
            {user && (
              <div className="user-menu">
                <span className="user-email">{user.attributes?.email}</span>
                <button className="btn-logout" onClick={handleLogout}>
                  Logout
                </button>
              </div>
            )}
          </div>
        </header>

        <main className="main-content">
          <Routes>
            <Route
              path="/login"
              element={user ? <Navigate to="/events" /> : <LoginPage onLoginSuccess={checkUser} />}
            />
            <Route
              path="/events"
              element={user ? <EventsPage user={user} /> : <Navigate to="/login" />}
            />
            <Route
              path="/history"
              element={user ? <BookingHistoryPage user={user} /> : <Navigate to="/login" />}
            />
            <Route path="/" element={<Navigate to={user ? '/events' : '/login'} />} />
          </Routes>
        </main>

        <footer className="footer">
          <div className="container">
            <p>&copy; 2026 Event Booking Platform. All rights reserved.</p>
            <p>Powered by AWS Serverless Architecture</p>
          </div>
        </footer>
      </div>
    </Router>
  );
}

export default App;
