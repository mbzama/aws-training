import React, { useState } from 'react';
import CognitoAuthService from '../services/CognitoAuthService';
import './LoginPage.css';

function LoginPage({ onLoginSuccess }) {
  const [mode, setMode] = useState('signin'); // 'signin' or 'signup'
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');

  const handleSignIn = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await CognitoAuthService.signIn(email, password);
      setSuccessMessage('Sign in successful! Redirecting...');
      setTimeout(() => {
        onLoginSuccess();
      }, 1000);
    } catch (error) {
      setError(error.message || 'Sign in failed');
    } finally {
      setLoading(false);
    }
  };

  const handleSignUp = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await CognitoAuthService.signUp(email, password, name);
      setSuccessMessage('Sign up successful! Please check your email for verification.');
      setEmail('');
      setPassword('');
      setName('');
      setTimeout(() => {
        setMode('signin');
        setSuccessMessage('');
      }, 3000);
    } catch (error) {
      setError(error.message || 'Sign up failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-container">
        <div className="login-card">
          <h2>{mode === 'signin' ? 'Sign In' : 'Create Account'}</h2>

          {error && <div className="alert alert-error">{error}</div>}
          {successMessage && <div className="alert alert-success">{successMessage}</div>}

          <form onSubmit={mode === 'signin' ? handleSignIn : handleSignUp}>
            {mode === 'signup' && (
              <div className="form-group">
                <label htmlFor="name">Full Name</label>
                <input
                  id="name"
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="John Doe"
                  required={mode === 'signup'}
                />
              </div>
            )}

            <div className="form-group">
              <label htmlFor="email">Email</label>
              <input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                required
              />
            </div>

            <div className="form-group">
              <label htmlFor="password">Password</label>
              <input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
              />
            </div>

            {mode === 'signup' && (
              <p className="password-hint">
                Password must be at least 8 characters and include uppercase, lowercase, numbers, and
                symbols.
              </p>
            )}

            <button type="submit" className="btn" disabled={loading}>
              {loading ? 'Processing...' : mode === 'signin' ? 'Sign In' : 'Create Account'}
            </button>
          </form>

          <div className="toggle-mode">
            {mode === 'signin' ? (
              <>
                <p>Don't have an account?</p>
                <button
                  type="button"
                  className="btn-link"
                  onClick={() => {
                    setMode('signup');
                    setError('');
                    setSuccessMessage('');
                  }}
                >
                  Sign Up
                </button>
              </>
            ) : (
              <>
                <p>Already have an account?</p>
                <button
                  type="button"
                  className="btn-link"
                  onClick={() => {
                    setMode('signin');
                    setError('');
                    setSuccessMessage('');
                  }}
                >
                  Sign In
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default LoginPage;
