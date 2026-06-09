import EventPublisher from "@/components/EventPublisher";
import EventSubscriber from "@/components/EventSubscriber";

export default function Home() {
  return (
    <main className="mx-auto max-w-6xl px-4 py-10">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-white">AWS AppSync Events API</h1>
        <p className="mt-2 text-gray-400">
          Real-time pub/sub demo — publish events on the left, subscribe to a channel on the right.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2 lg:items-start">
        <EventPublisher defaultChannel="/default/chat" />
        <div className="h-[600px]">
          <EventSubscriber defaultChannel="/default/chat" />
        </div>
      </div>

      <footer className="mt-12 border-t border-gray-800 pt-6 text-center text-xs text-gray-600">
        AppSync Events API &mdash; API_KEY auth &mdash; for production use Cognito or IAM
      </footer>
    </main>
  );
}
