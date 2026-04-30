const MOCK_USERS = [
  { id: 1, name: 'Alice Johnson', email: 'alice@example.com', role: 'Admin', status: 'Active' },
  { id: 2, name: 'Bob Smith', email: 'bob@example.com', role: 'User', status: 'Active' },
  { id: 3, name: 'Carol White', email: 'carol@example.com', role: 'Editor', status: 'Inactive' },
  { id: 4, name: 'Dave Brown', email: 'dave@example.com', role: 'User', status: 'Active' },
  { id: 5, name: 'Eve Davis', email: 'eve@example.com', role: 'Moderator', status: 'Active' },
  { id: 6, name: 'Frank Miller', email: 'frank@example.com', role: 'User', status: 'Pending' },
]

const statusColor: Record<string, string> = {
  Active: '#22c55e',
  Inactive: '#ef4444',
  Pending: '#f59e0b',
}

export default function UserList() {
  return (
    <div style={styles.container}>
      <h1 style={styles.heading}>Users</h1>
      <p style={styles.subheading}>{MOCK_USERS.length} registered users</p>
      <div style={styles.tableWrapper}>
        <table style={styles.table}>
          <thead>
            <tr>
              <th style={styles.th}>ID</th>
              <th style={styles.th}>Name</th>
              <th style={styles.th}>Email</th>
              <th style={styles.th}>Role</th>
              <th style={styles.th}>Status</th>
            </tr>
          </thead>
          <tbody>
            {MOCK_USERS.map((user, i) => (
              <tr key={user.id} style={{ background: i % 2 === 0 ? '#fff' : '#f9fafb' }}>
                <td style={styles.td}>{user.id}</td>
                <td style={{ ...styles.td, fontWeight: 600 }}>{user.name}</td>
                <td style={styles.td}>{user.email}</td>
                <td style={styles.td}>{user.role}</td>
                <td style={styles.td}>
                  <span
                    style={{
                      ...styles.badge,
                      background: `${statusColor[user.status]}22`,
                      color: statusColor[user.status],
                      border: `1px solid ${statusColor[user.status]}55`,
                    }}
                  >
                    {user.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    padding: '2rem',
    maxWidth: '900px',
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
  tableWrapper: {
    overflowX: 'auto',
    borderRadius: '8px',
    border: '1px solid #e2e8f0',
    boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
  },
  th: {
    padding: '12px 16px',
    textAlign: 'left',
    background: '#f8fafc',
    borderBottom: '2px solid #e2e8f0',
    color: '#475569',
    fontSize: '0.8rem',
    fontWeight: 600,
    textTransform: 'uppercase',
    letterSpacing: '0.05em',
  },
  td: {
    padding: '12px 16px',
    borderBottom: '1px solid #f1f5f9',
    color: '#334155',
    fontSize: '0.9rem',
  },
  badge: {
    display: 'inline-block',
    padding: '2px 10px',
    borderRadius: '999px',
    fontSize: '0.78rem',
    fontWeight: 600,
  },
}
