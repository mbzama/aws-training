import { useState } from 'react'

interface Module {
  id: string
  title: string
  description: string
  path: string
  icon: string
  accentColor: string
  features: string[]
  tech: string[]
}

const MODULES: Module[] = [
  {
    id: 'users',
    title: 'Users',
    description: 'Manage and browse registered platform users with role and status details.',
    path: '/users',
    icon: '👥',
    accentColor: '#6366f1',
    features: ['User directory', 'Role management', 'Status tracking'],
    tech: ['React 18', 'Vite', 'React Router v7'],
  },
  {
    id: 'movies',
    title: 'Movies',
    description: 'Explore a curated catalog of movies with genres, ratings, and directors.',
    path: '/movies',
    icon: '🎬',
    accentColor: '#f59e0b',
    features: ['Movie catalog', 'Genre filtering', 'Star ratings'],
    tech: ['React 18', 'Vite', 'React Router v7'],
  },
]

function ModuleCard({ module }: { module: Module }) {
  const [hovered, setHovered] = useState(false)

  return (
    <a
      href={module.path}
      style={{
        ...styles.card,
        transform: hovered ? 'translateY(-6px)' : 'translateY(0)',
        boxShadow: hovered
          ? `0 20px 40px rgba(0,0,0,0.4), 0 0 0 1px ${module.accentColor}44`
          : '0 4px 16px rgba(0,0,0,0.3)',
        borderColor: hovered ? `${module.accentColor}66` : '#1e293b',
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      {/* Top accent bar */}
      <div style={{ ...styles.accentBar, background: module.accentColor }} />

      <div style={styles.cardInner}>
        {/* Header */}
        <div style={styles.cardHeader}>
          <span style={styles.icon}>{module.icon}</span>
          <div>
            <h2 style={styles.cardTitle}>{module.title}</h2>
            <code style={{ ...styles.pathBadge, color: module.accentColor }}>
              {module.path}
            </code>
          </div>
        </div>

        {/* Description */}
        <p style={styles.description}>{module.description}</p>

        {/* Features */}
        <ul style={styles.featureList}>
          {module.features.map((f) => (
            <li key={f} style={styles.featureItem}>
              <span style={{ color: module.accentColor, marginRight: '8px' }}>✓</span>
              {f}
            </li>
          ))}
        </ul>

        {/* Tech tags */}
        <div style={styles.tags}>
          {module.tech.map((t) => (
            <span key={t} style={styles.tag}>{t}</span>
          ))}
        </div>

        {/* CTA */}
        <div
          style={{
            ...styles.cta,
            background: `${module.accentColor}22`,
            borderColor: `${module.accentColor}44`,
            color: module.accentColor,
          }}
        >
          Open {module.title} →
        </div>
      </div>
    </a>
  )
}

export default function LandingPage() {
  return (
    <div style={styles.page}>
      {/* Background grid */}
      <div style={styles.grid} aria-hidden="true" />

      <div style={styles.content}>
        {/* Hero */}
        <header style={styles.hero}>
          <div style={styles.badge}>Micro Frontend Platform</div>
          <h1 style={styles.heading}>
            Modular{' '}
            <span style={styles.gradientText}>Applications</span>
          </h1>
          <p style={styles.subheading}>
            Independent React SPAs composed via Module Federation and single-spa.
            Each module is deployed separately to S3 and served through CloudFront.
          </p>
        </header>

        {/* Module cards */}
        <main>
          <p style={styles.sectionLabel}>Available Modules</p>
          <div style={styles.cardGrid}>
            {MODULES.map((mod) => (
              <ModuleCard key={mod.id} module={mod} />
            ))}
          </div>
        </main>

        {/* Architecture note */}
        <section style={styles.archBox}>
          <h3 style={styles.archTitle}>Deployment Architecture</h3>
          <div style={styles.archFlow}>
            {['Browser', 'CloudFront CDN', 'S3 Bucket', '/users  /movies'].map((node, i, arr) => (
              <div key={node} style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span style={styles.archNode}>{node}</span>
                {i < arr.length - 1 && <span style={styles.arrow}>→</span>}
              </div>
            ))}
          </div>
        </section>

        <footer style={styles.footer}>
          Built with React 18 · Vite · React Router v7 · Module Federation · single-spa
        </footer>
      </div>
    </div>
  )
}

const styles: Record<string, React.CSSProperties> = {
  page: {
    minHeight: '100vh',
    background: '#0f172a',
    color: '#e2e8f0',
    position: 'relative',
    overflow: 'hidden',
  },
  grid: {
    position: 'absolute',
    inset: 0,
    backgroundImage:
      'linear-gradient(rgba(99,102,241,0.05) 1px, transparent 1px), linear-gradient(90deg, rgba(99,102,241,0.05) 1px, transparent 1px)',
    backgroundSize: '60px 60px',
    pointerEvents: 'none',
  },
  content: {
    position: 'relative',
    maxWidth: '900px',
    margin: '0 auto',
    padding: '4rem 1.5rem 3rem',
  },
  hero: {
    textAlign: 'center',
    marginBottom: '3.5rem',
  },
  badge: {
    display: 'inline-block',
    padding: '4px 14px',
    borderRadius: '999px',
    border: '1px solid #334155',
    background: '#1e293b',
    color: '#94a3b8',
    fontSize: '0.75rem',
    fontWeight: 600,
    letterSpacing: '0.08em',
    textTransform: 'uppercase',
    marginBottom: '1.25rem',
  },
  heading: {
    fontSize: 'clamp(2.2rem, 6vw, 3.5rem)',
    fontWeight: 800,
    lineHeight: 1.1,
    marginBottom: '1rem',
    color: '#f1f5f9',
  },
  gradientText: {
    background: 'linear-gradient(135deg, #6366f1, #f59e0b)',
    WebkitBackgroundClip: 'text',
    WebkitTextFillColor: 'transparent',
    backgroundClip: 'text',
  },
  subheading: {
    fontSize: '1rem',
    color: '#64748b',
    maxWidth: '560px',
    margin: '0 auto',
    lineHeight: 1.7,
  },
  sectionLabel: {
    fontSize: '0.75rem',
    fontWeight: 700,
    letterSpacing: '0.1em',
    textTransform: 'uppercase',
    color: '#475569',
    marginBottom: '1rem',
  },
  cardGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))',
    gap: '1.25rem',
    marginBottom: '3rem',
  },
  card: {
    display: 'block',
    textDecoration: 'none',
    background: '#111827',
    border: '1px solid #1e293b',
    borderRadius: '14px',
    overflow: 'hidden',
    transition: 'transform 0.2s ease, box-shadow 0.2s ease, border-color 0.2s ease',
    cursor: 'pointer',
  },
  accentBar: {
    height: '3px',
    width: '100%',
  },
  cardInner: {
    padding: '1.5rem',
    display: 'flex',
    flexDirection: 'column',
    gap: '1rem',
  },
  cardHeader: {
    display: 'flex',
    alignItems: 'center',
    gap: '1rem',
  },
  icon: {
    fontSize: '2.2rem',
    lineHeight: 1,
  },
  cardTitle: {
    fontSize: '1.25rem',
    fontWeight: 700,
    color: '#f1f5f9',
    marginBottom: '2px',
  },
  pathBadge: {
    fontSize: '0.78rem',
    fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
    fontWeight: 600,
  },
  description: {
    fontSize: '0.9rem',
    color: '#64748b',
    lineHeight: 1.65,
  },
  featureList: {
    listStyle: 'none',
    display: 'flex',
    flexDirection: 'column',
    gap: '6px',
  },
  featureItem: {
    fontSize: '0.85rem',
    color: '#94a3b8',
    display: 'flex',
    alignItems: 'center',
  },
  tags: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '6px',
  },
  tag: {
    padding: '3px 10px',
    borderRadius: '6px',
    background: '#1e293b',
    border: '1px solid #334155',
    fontSize: '0.72rem',
    color: '#64748b',
    fontWeight: 500,
  },
  cta: {
    padding: '10px 16px',
    borderRadius: '8px',
    border: '1px solid',
    fontSize: '0.85rem',
    fontWeight: 600,
    textAlign: 'center',
    transition: 'opacity 0.15s',
  },
  archBox: {
    background: '#0d1117',
    border: '1px solid #1e293b',
    borderRadius: '12px',
    padding: '1.5rem',
    marginBottom: '2.5rem',
  },
  archTitle: {
    fontSize: '0.8rem',
    fontWeight: 700,
    letterSpacing: '0.08em',
    textTransform: 'uppercase',
    color: '#475569',
    marginBottom: '1rem',
  },
  archFlow: {
    display: 'flex',
    flexWrap: 'wrap',
    alignItems: 'center',
    gap: '8px',
  },
  archNode: {
    padding: '6px 14px',
    borderRadius: '8px',
    background: '#1e293b',
    border: '1px solid #334155',
    fontSize: '0.82rem',
    color: '#94a3b8',
    fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
  },
  arrow: {
    color: '#334155',
    fontSize: '1.1rem',
  },
  footer: {
    textAlign: 'center',
    fontSize: '0.78rem',
    color: '#334155',
    borderTop: '1px solid #1e293b',
    paddingTop: '1.5rem',
  },
}
