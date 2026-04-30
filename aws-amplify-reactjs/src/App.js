import React from 'react';
import './App.css';

// Feature card data — easy to extend or pull from an API in the future
const features = [
  {
    id: 1,
    icon: '⚡',
    title: 'Fast',
    description:
      'Global CDN delivery via Amazon CloudFront ensures your app loads in milliseconds, no matter where your users are located.',
  },
  {
    id: 2,
    icon: '🔒',
    title: 'Secure',
    description:
      'Built-in HTTPS with ACM-managed TLS certificates, AWS WAF integration, and IAM-based access controls keep your app protected.',
  },
  {
    id: 3,
    icon: '📈',
    title: 'Scalable',
    description:
      'AWS Amplify auto-scales to handle any traffic spike without configuration. Pay only for what you use — zero idle costs.',
  },
];

// FeatureCard — presentational component for each feature tile
function FeatureCard({ icon, title, description }) {
  return (
    <div className="feature-card">
      <div className="feature-icon" aria-hidden="true">
        {icon}
      </div>
      <h3 className="feature-title">{title}</h3>
      <p className="feature-description">{description}</p>
    </div>
  );
}

// Header — top navigation bar
function Header() {
  return (
    <header className="header">
      <div className="header-inner container">
        <div className="logo">
          <span className="logo-icon" aria-hidden="true">☁️</span>
          <span className="logo-text">AWS Amplify React App</span>
        </div>
        <nav className="nav" aria-label="Main navigation">
          <a href="#features" className="nav-link">Features</a>
          <a href="#about" className="nav-link">About</a>
          <a
            href="https://docs.amplify.aws"
            className="nav-link nav-link--cta"
            target="_blank"
            rel="noopener noreferrer"
          >
            Docs
          </a>
        </nav>
      </div>
    </header>
  );
}

// Hero — prominent landing section
function Hero() {
  return (
    <section className="hero" aria-labelledby="hero-heading">
      <div className="hero-inner container">
        <div className="hero-badge">Production Ready</div>
        <h1 id="hero-heading" className="hero-heading">
          Deployed on <span className="hero-highlight">AWS Amplify</span>
        </h1>
        <p className="hero-subheading">
          A modern React application hosted on AWS Amplify with a custom domain,
          HTTPS, and global CDN — built and deployed in minutes.
        </p>
        <div className="hero-actions">
          <a href="#features" className="btn btn--primary">
            Explore Features
          </a>
          <a
            href="https://github.com"
            className="btn btn--secondary"
            target="_blank"
            rel="noopener noreferrer"
          >
            View on GitHub
          </a>
        </div>
        <div className="hero-meta">
          <span className="hero-meta-item">
            <span className="hero-meta-dot hero-meta-dot--green" aria-hidden="true" />
            Live on app-dev.zamait.com
          </span>
          <span className="hero-meta-item">
            <span className="hero-meta-dot hero-meta-dot--blue" aria-hidden="true" />
            Auto-deploy from main branch
          </span>
        </div>
      </div>
    </section>
  );
}

// FeaturesSection — three-column feature cards
function FeaturesSection() {
  return (
    <section id="features" className="features-section" aria-labelledby="features-heading">
      <div className="container">
        <div className="section-header">
          <h2 id="features-heading" className="section-title">
            Why AWS Amplify?
          </h2>
          <p className="section-subtitle">
            Everything you need to ship a production-grade web app without managing
            servers.
          </p>
        </div>
        <div className="features-grid">
          {features.map((feature) => (
            <FeatureCard key={feature.id} {...feature} />
          ))}
        </div>
      </div>
    </section>
  );
}

// AboutSection — brief project context
function AboutSection() {
  return (
    <section id="about" className="about-section" aria-labelledby="about-heading">
      <div className="container about-inner">
        <div className="about-text">
          <h2 id="about-heading" className="section-title">
            About This Project
          </h2>
          <p className="about-description">
            This application demonstrates a full-stack deployment pipeline using
            AWS Amplify Hosting, Terraform for infrastructure-as-code, and a custom
            domain configured through Amazon Certificate Manager (ACM) and GoDaddy
            DNS.
          </p>
          <ul className="about-list">
            <li>React 18 frontend with Create React App</li>
            <li>AWS Amplify Hosting with Git-based CI/CD</li>
            <li>Custom domain: <code>app-dev.zamait.com</code></li>
            <li>ACM TLS certificate with DNS validation</li>
            <li>Terraform IaC for repeatable infrastructure</li>
          </ul>
        </div>
        <div className="about-stack">
          <h3 className="about-stack-title">Tech Stack</h3>
          <div className="stack-badges">
            <span className="badge badge--orange">React 18</span>
            <span className="badge badge--blue">AWS Amplify</span>
            <span className="badge badge--purple">Terraform</span>
            <span className="badge badge--green">ACM / HTTPS</span>
            <span className="badge badge--gray">GitHub CI/CD</span>
          </div>
        </div>
      </div>
    </section>
  );
}

// Footer — bottom bar
function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="footer">
      <div className="container footer-inner">
        <p className="footer-copy">
          &copy; {year} AWS Amplify React App &mdash; Deployed on{' '}
          <a
            href="https://aws.amazon.com/amplify/"
            className="footer-link"
            target="_blank"
            rel="noopener noreferrer"
          >
            AWS Amplify
          </a>
        </p>
        <p className="footer-domain">app-dev.zamait.com</p>
      </div>
    </footer>
  );
}

// App — root component
function App() {
  return (
    <div className="app">
      <Header />
      <main>
        <Hero />
        <FeaturesSection />
        <AboutSection />
      </main>
      <Footer />
    </div>
  );
}

export default App;
