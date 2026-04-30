import React from 'react'
import { createRoot } from 'react-dom/client'
import singleSpaReact from 'single-spa-react'
import App from './App'

// Standalone development mode (not hosted by single-spa)
if (!(window as any).__POWERED_BY_SINGLE_SPA__) {
  createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  )
}

// single-spa lifecycle hooks — React 18 compatible via renderType: 'createRoot'
const lifecycles = singleSpaReact({
  React,
  ReactDOM: { createRoot } as any,
  rootComponent: App,
  renderType: 'createRoot',
  errorBoundary(err: Error) {
    return (
      <div style={{ color: 'red', padding: '1rem' }}>
        Movies App Error: {err.message}
      </div>
    )
  },
})

export const { bootstrap, mount, unmount } = lifecycles
