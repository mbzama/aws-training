const logger = require('./logger');

class AppError extends Error {
  constructor(message, statusCode = 500, code = 'INTERNAL_ERROR') {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.timestamp = new Date().toISOString();
  }
}

class ValidationError extends AppError {
  constructor(message) {
    super(message, 400, 'VALIDATION_ERROR');
  }
}

class NotFoundError extends AppError {
  constructor(message) {
    super(message, 404, 'NOT_FOUND');
  }
}

class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super(message, 401, 'UNAUTHORIZED');
  }
}

class ConflictError extends AppError {
  constructor(message) {
    super(message, 409, 'CONFLICT');
  }
}

const createErrorResponse = (error, requestId) => {
  logger.error('API Error', error, { requestId });

  let statusCode = 500;
  let code = 'INTERNAL_ERROR';
  let message = 'Internal server error';

  if (error instanceof AppError) {
    statusCode = error.statusCode;
    code = error.code;
    message = error.message;
  } else if (error.code === 'ValidationException') {
    statusCode = 400;
    code = 'VALIDATION_ERROR';
    message = error.message;
  } else if (error.code === 'ResourceNotFoundException') {
    statusCode = 404;
    code = 'NOT_FOUND';
    message = 'Resource not found';
  }

  return {
    statusCode,
    body: JSON.stringify({
      error: {
        code,
        message,
        requestId,
        timestamp: new Date().toISOString(),
      },
    }),
    headers: {
      'Content-Type': 'application/json',
      'X-Request-ID': requestId,
    },
  };
};

const createSuccessResponse = (data, statusCode = 200, requestId) => {
  return {
    statusCode,
    body: JSON.stringify({
      success: true,
      data,
      requestId,
      timestamp: new Date().toISOString(),
    }),
    headers: {
      'Content-Type': 'application/json',
      'X-Request-ID': requestId,
    },
  };
};

module.exports = {
  AppError,
  ValidationError,
  NotFoundError,
  UnauthorizedError,
  ConflictError,
  createErrorResponse,
  createSuccessResponse,
};
