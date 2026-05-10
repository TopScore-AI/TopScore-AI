'use client';
import { motion } from 'framer-motion';
import { Menu, X, Sparkles } from 'lucide-react';
import { useState, useEffect } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { usePathname } from 'next/navigation';
import { useLocale } from '@/i18n';

export default function Nav() {
  const [isOpen, setIsOpen] = useState(false);
  const [isScrolled, setIsScrolled] = useState(false);
  const pathname = usePathname();
  const { t } = useLocale();

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  useEffect(() => {
    setIsOpen(false);
  }, [pathname]);

  const navLinks = [
    { href: '/features', key: 'nav.features' },
    { href: '/how-it-works', key: 'nav.howItWorks' },
    { href: '/tools', key: 'nav.tools' },
    { href: '/pricing', key: 'nav.pricing' },
    { href: '/contact', key: 'contact.label' },
  ];

  return (
    <nav className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${isScrolled ? 'bg-white/80 backdrop-blur-lg border-b border-slate-200/50 py-3 shadow-sm' : 'bg-transparent py-5'}`}>
      <div className="max-w-7xl mx-auto px-4 sm:px-10 flex items-center justify-between">
        <Link href="/" className="flex items-center gap-3">
          <Image 
            src="/logo.png" 
            alt="TopScore AI" 
            width={36} 
            height={36} 
            className="rounded-xl shadow-lg shadow-indigo-200"
          />
          <span className="text-xl font-display font-black tracking-tight text-slate-900">TopScore AI</span>
        </Link>


        <div className="hidden lg:flex items-center gap-10 text-[13px] font-bold text-slate-500 uppercase tracking-widest">
          {navLinks.map(({ href, key }) => (
            <Link 
              key={href} 
              href={href} 
              className={`hover:text-brand-primary transition-colors py-1 relative group ${pathname === href ? 'text-brand-primary' : ''}`}
            >
              {t(key as any)}
              <span className={`absolute bottom-0 left-0 h-0.5 bg-brand-primary transition-all group-hover:w-full ${pathname === href ? 'w-full' : 'w-0'}`} />
            </Link>
          ))}
        </div>

        <div className="hidden sm:flex items-center gap-4">
          <a 
            href="https://app.topscoreapp.ai"
            className="bg-slate-900 text-white px-6 py-2.5 rounded-full text-xs font-bold hover:bg-brand-primary transition-all shadow-xl shadow-slate-200 hover:shadow-indigo-200"
          >
            Start Learning for Free
          </a>
        </div>

        <button 
          className="lg:hidden p-2 text-slate-600 hover:bg-slate-100 rounded-lg transition-colors" 
          onClick={() => setIsOpen(!isOpen)}
          aria-expanded={isOpen}
          aria-label="Toggle Navigation Menu"
        >
          {isOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
        </button>
      </div>

      {isOpen && (
        <motion.div 
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="absolute top-full left-0 right-0 bg-white border-b border-slate-200 px-6 py-10 space-y-6 lg:hidden shadow-2xl"
        >
          <div className="flex flex-col gap-6">
            {navLinks.map(({ href, key }) => (
              <Link 
                key={href} 
                href={href} 
                className={`text-xl font-display font-bold ${pathname === href ? 'text-brand-primary' : 'text-slate-800'}`}
                onClick={() => setIsOpen(false)}
              >
                {t(key as any)}
              </Link>
            ))}
          </div>
          <div className="pt-6 border-t border-slate-100">
            <a 
              href="https://app.topscoreapp.ai"
              className="w-full bg-slate-900 text-white py-4 rounded-2xl font-bold text-center block shadow-lg shadow-slate-200"
            >
              {t('nav.download' as any)}
            </a>
          </div>
        </motion.div>
      )}
    </nav>
  );
}

