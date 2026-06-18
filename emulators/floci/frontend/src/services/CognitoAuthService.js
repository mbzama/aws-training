const API_ENDPOINT = process.env.REACT_APP_API_ENDPOINT || 'http://localhost:5000';

class CognitoAuthService {
  static async signUp(email, password, name) {
    try {
      const response = await fetch(`${API_ENDPOINT}/auth/signup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, name }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Sign up failed');
      }

      const data = await response.json();
      localStorage.setItem('user', JSON.stringify({ email, name }));

      return {
        userSub: data.userSub,
        username: email,
      };
    } catch (error) {
      throw new Error(error.message || 'Sign up failed');
    }
  }

  static async signIn(email, password) {
    try {
      const response = await fetch(`${API_ENDPOINT}/auth/signin`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Sign in failed');
      }

      const data = await response.json();

      localStorage.setItem('idToken', data.idToken);
      localStorage.setItem('accessToken', data.accessToken);
      localStorage.setItem('refreshToken', data.refreshToken);
      localStorage.setItem('user', JSON.stringify({ email }));
      localStorage.setItem('expiresAt', Date.now() + data.expiresIn * 1000);

      return {
        accessToken: data.accessToken,
        idToken: data.idToken,
        refreshToken: data.refreshToken,
        expiresIn: data.expiresIn,
      };
    } catch (error) {
      throw new Error(error.message || 'Sign in failed. Please check your credentials.');
    }
  }

  static async signOut() {
    try {
      const accessToken = localStorage.getItem('accessToken');

      if (accessToken) {
        await fetch(`${API_ENDPOINT}/auth/signout`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`,
          },
        });
      }
    } catch (error) {
      console.warn('Sign out error:', error.message);
    } finally {
      localStorage.removeItem('idToken');
      localStorage.removeItem('accessToken');
      localStorage.removeItem('refreshToken');
      localStorage.removeItem('user');
      localStorage.removeItem('expiresAt');
    }
  }

  static async getCurrentUser() {
    try {
      const user = localStorage.getItem('user');
      const idToken = localStorage.getItem('idToken');
      const accessToken = localStorage.getItem('accessToken');
      const expiresAt = localStorage.getItem('expiresAt');

      if (!user || !idToken || !accessToken) {
        return null;
      }

      // Check if token is expired
      if (expiresAt && Date.now() >= parseInt(expiresAt)) {
        await this.signOut();
        return null;
      }

      const parsedUser = JSON.parse(user);
      return {
        username: parsedUser.email,
        attributes: parsedUser,
        idToken,
        accessToken,
      };
    } catch (error) {
      console.warn('Error retrieving user:', error);
      localStorage.clear();
      return null;
    }
  }

  static async getIdToken() {
    const expiresAt = localStorage.getItem('expiresAt');

    if (expiresAt && Date.now() >= parseInt(expiresAt)) {
      await this.signOut();
      return null;
    }

    return localStorage.getItem('idToken');
  }
}

export default CognitoAuthService;
