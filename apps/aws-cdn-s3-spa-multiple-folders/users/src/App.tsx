import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import UserList from './components/UserList'

const router = createBrowserRouter(
  [
    {
      path: '/',
      element: <UserList />,
    },
    {
      path: '*',
      element: <UserList />,
    },
  ],
  { basename: '/users' }
)

export default function App() {
  return <RouterProvider router={router} />
}
