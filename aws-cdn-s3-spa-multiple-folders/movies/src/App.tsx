import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import MovieList from './components/MovieList'

const router = createBrowserRouter(
  [
    {
      path: '/',
      element: <MovieList />,
    },
    {
      path: '*',
      element: <MovieList />,
    },
  ],
  { basename: '/movies' }
)

export default function App() {
  return <RouterProvider router={router} />
}
