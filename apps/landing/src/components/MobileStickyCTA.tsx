'use client';
import { motion, AnimatePresence } from 'framer-motion';
import { useState, useEffect } from 'react';
import { Layout, ArrowRight } from 'lucide-react';

export default function MobileStickyCTA() {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      // Show after scrolling 600px
      setIsVisible(window.scrollY > 600);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ y: 100, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 100, opacity: 0 }}
          className="fixed bottom-6 left-4 right-4 z-50 sm:hidden"
        >
          <a
            href="https://app.topscoreapp.ai"
            className="flex items-center justify-between bg-slate-900 border border-white/10 text-white p-4 rounded-3xl shadow-2xl glass-effect"
          >
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-brand-primary rounded-xl flex items-center justify-center">
                <Layout className="w-5 h-5 text-white" />
              </div>
              <div className="flex flex-col">
                <span className="text-sm font-black tracking-tight">TopScore AI</span>
                <span className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">Start Learning Free</span>
              </div>
            </div>
            <div className="flex items-center gap-2 bg-brand-primary px-4 py-2 rounded-2xl font-black text-xs uppercase tracking-wider">
              Start
              <ArrowRight className="w-3.5 h-3.5" />
            </div>
          </a>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
