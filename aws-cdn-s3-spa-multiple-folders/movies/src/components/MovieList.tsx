const MOCK_MOVIES = [
  { id: 1, title: 'Inception', genre: 'Sci-Fi', year: 2010, rating: 8.8, director: 'Christopher Nolan' },
  { id: 2, title: 'The Dark Knight', genre: 'Action', year: 2008, rating: 9.0, director: 'Christopher Nolan' },
  { id: 3, title: 'Interstellar', genre: 'Sci-Fi', year: 2014, rating: 8.6, director: 'Christopher Nolan' },
  { id: 4, title: 'Parasite', genre: 'Drama', year: 2019, rating: 8.5, director: 'Bong Joon-ho' },
  { id: 5, title: 'The Shawshank Redemption', genre: 'Drama', year: 1994, rating: 9.3, director: 'Frank Darabont' },
  { id: 6, title: 'Pulp Fiction', genre: 'Crime', year: 1994, rating: 8.9, director: 'Quentin Tarantino' },
  { id: 7, title: 'The Godfather', genre: 'Crime', year: 1972, rating: 9.2, director: 'Francis Ford Coppola' },
  { id: 8, title: 'Whiplash', genre: 'Drama', year: 2014, rating: 8.5, director: 'Damien Chazelle' },
]

const genreColor: Record<string, string> = {
  'Sci-Fi': '#6366f1',
  Action: '#f97316',
  Drama: '#14b8a6',
  Crime: '#8b5cf6',
}

function StarRating({ rating }: { rating: number }) {
  const stars = Math.round(rating / 2)
  return (
    <span>
      {'★'.repeat(stars)}{'☆'.repeat(5 - stars)}
      <span style={{ marginLeft: '6px', color: '#64748b', fontSize: '0.85rem' }}>{rating}</span>
    </span>
  )
}

export default function MovieList() {
  return (
    <div style={styles.container}>
      <h1 style={styles.heading}>Movies</h1>
      <p style={styles.subheading}>{MOCK_MOVIES.length} titles in the catalog</p>
      <div style={styles.grid}>
        {MOCK_MOVIES.map((movie) => {
          const color = genreColor[movie.genre] ?? '#64748b'
          return (
            <div key={movie.id} style={styles.card}>
              <div style={{ ...styles.cardAccent, background: color }} />
              <div style={styles.cardBody}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '8px' }}>
                  <h2 style={styles.title}>{movie.title}</h2>
                  <span
                    style={{
                      ...styles.genre,
                      background: `${color}22`,
                      color,
                      border: `1px solid ${color}44`,
                    }}
                  >
                    {movie.genre}
                  </span>
                </div>
                <p style={styles.director}>{movie.director}</p>
                <div style={styles.footer}>
                  <span style={styles.year}>{movie.year}</span>
                  <span style={{ color: '#f59e0b' }}>
                    <StarRating rating={movie.rating} />
                  </span>
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    padding: '2rem',
    maxWidth: '1100px',
    margin: '0 auto',
  },
  heading: {
    fontSize: '2rem',
    fontWeight: 700,
    color: '#1e293b',
    marginBottom: '0.25rem',
  },
  subheading: {
    color: '#64748b',
    marginBottom: '1.5rem',
    fontSize: '0.95rem',
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
    gap: '1rem',
  },
  card: {
    borderRadius: '10px',
    border: '1px solid #e2e8f0',
    overflow: 'hidden',
    boxShadow: '0 1px 3px rgba(0,0,0,0.08)',
    background: '#fff',
    transition: 'box-shadow 0.2s',
  },
  cardAccent: {
    height: '4px',
  },
  cardBody: {
    padding: '1rem',
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  },
  title: {
    fontSize: '1rem',
    fontWeight: 700,
    color: '#1e293b',
    lineHeight: 1.3,
  },
  genre: {
    display: 'inline-block',
    padding: '2px 10px',
    borderRadius: '999px',
    fontSize: '0.72rem',
    fontWeight: 600,
    whiteSpace: 'nowrap',
    flexShrink: 0,
  },
  director: {
    fontSize: '0.85rem',
    color: '#64748b',
  },
  footer: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: '4px',
  },
  year: {
    fontSize: '0.82rem',
    color: '#94a3b8',
    fontWeight: 600,
  },
}
