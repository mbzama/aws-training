import winston from 'winston';

const { combine, timestamp, colorize, printf, json } = winston.format;

const consoleFormat = printf(({ level, message, timestamp, service, ...meta }) => {
  const metaStr = Object.keys(meta).length ? `\n  ${JSON.stringify(meta, null, 2)}` : '';
  return `[${timestamp}] [${service || 'APP'}] ${level}: ${message}${metaStr}`;
});

export function createLogger(service: string) {
  return winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    defaultMeta: { service },
    transports: [
      new winston.transports.Console({
        format: combine(
          colorize({ all: true }),
          timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
          consoleFormat
        ),
      }),
    ],
  });
}

export const appLogger = createLogger('NEXT-API');
