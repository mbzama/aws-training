'use client'

import { useEffect, useState } from 'react'

interface Product {
  id: number
  name: string
  price: number
  category: string
  inStock: boolean
}

export default function ProductsPage() {
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchProducts = async () => {
      try {
        const url = process.env.NEXT_PUBLIC_API_URL
          ? `${process.env.NEXT_PUBLIC_API_URL}/api/products`
          : 'http://mock-api.mock-api.svc.cluster.local/api/products'

        const res = await fetch(url)
        if (!res.ok) throw new Error(`Failed to fetch products: ${res.status}`)
        const data = await res.json()
        setProducts(data)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load products')
        // Set fallback products for demo
        setProducts([
          { id: 1, name: 'Sample Product 1', price: 29.99, category: 'Electronics', inStock: true },
          { id: 2, name: 'Sample Product 2', price: 49.99, category: 'Clothing', inStock: true },
        ])
      } finally {
        setLoading(false)
      }
    }

    fetchProducts()
  }, [])

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-xl text-gray-500">Loading products...</div>
      </div>
    )
  }

  return (
    <div>
      <h1 className="text-4xl font-bold mb-8">Products</h1>
      {error && (
        <div className="mb-4 p-4 bg-yellow-100 text-yellow-800 rounded">
          {error} - Showing sample data
        </div>
      )}
      <div className="overflow-x-auto rounded-lg border border-gray-200 dark:border-gray-700">
        <table className="w-full text-sm text-left">
          <thead className="bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 uppercase text-xs">
            <tr>
              <th className="px-6 py-3">ID</th>
              <th className="px-6 py-3">Name</th>
              <th className="px-6 py-3">Category</th>
              <th className="px-6 py-3">Price</th>
              <th className="px-6 py-3">In Stock</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
            {products.map((product) => (
              <tr key={product.id} className="bg-white dark:bg-gray-900 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                <td className="px-6 py-4 text-gray-500">{product.id}</td>
                <td className="px-6 py-4 font-medium text-gray-900 dark:text-white">{product.name}</td>
                <td className="px-6 py-4">
                  <span className="px-2 py-1 text-xs font-semibold rounded-full bg-indigo-100 text-indigo-700 dark:bg-indigo-900 dark:text-indigo-300">
                    {product.category}
                  </span>
                </td>
                <td className="px-6 py-4 font-semibold text-indigo-600">${product.price.toFixed(2)}</td>
                <td className="px-6 py-4">
                  {product.inStock ? (
                    <span className="px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300">
                      In Stock
                    </span>
                  ) : (
                    <span className="px-2 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300">
                      Out of Stock
                    </span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
