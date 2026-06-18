const LOG_LEVEL = process.env.LOG_LEVEL || 'INFO';

const LEVELS = {
  DEBUG: 0,
  INFO: 1,
  WARN: 2,
  ERROR: 3,
};

const currentLevel = LEVELS[LOG_LEVEL] || LEVELS.INFO;

const logger = {
  debug: (message, data = {}) => {
    if (currentLevel <= LEVELS.DEBUG) {
      console.log(JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'DEBUG',
        message,
        ...data,
      }));
    }
  },

  info: (message, data = {}) => {
    if (currentLevel <= LEVELS.INFO) {
      console.log(JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'INFO',
        message,
        ...data,
      }));
    }
  },

  warn: (message, data = {}) => {
    if (currentLevel <= LEVELS.WARN) {
      console.warn(JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'WARN',
        message,
        ...data,
      }));
    }
  },

  error: (message, error = null, data = {}) => {
    if (currentLevel <= LEVELS.ERROR) {
      console.error(JSON.stringify({
        timestamp: new Date().toISOString(),
        level: 'ERROR',
        message,
        error: error ? {
          message: error.message,
          stack: error.stack,
          code: error.code,
        } : null,
        ...data,
      }));
    }
  },
};

module.exports = logger;
