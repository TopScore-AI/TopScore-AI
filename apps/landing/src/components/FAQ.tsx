'use client';
import { motion, AnimatePresence } from 'framer-motion';
import { useState } from 'react';
import { Plus, Minus, HelpCircle } from 'lucide-react';
import JsonLd from './JsonLd';

const faqs = [
  {
    q: "Does it cover the new CBE (Competency Based Education)?",
    a: "Yes! TopScore AI is fully updated with the Kenyan CBE curriculum for Primary and Junior Secondary levels, including specific strands and sub-strands."
  },
  {
    q: "Is the AI specific to the Kenyan syllabus (KCSE/KCPE)?",
    a: "Absolutely. We use RAG (Retrieval Augmented Generation) to ground our AI in Kenyan textbooks, past papers, and KICD-approved materials to ensure accuracy."
  },
  {
    q: "Can I use it for IGCSE or IB?",
    a: "Yes, our multi-curriculum engine allows you to switch between 8-4-4, CBE, and International systems (IGCSE, A-Levels, IB) seamlessly."
  },
  {
    q: "How does the 'AI Camera' work for math?",
    a: "Using Gemini's multimodal capabilities, you simply point your camera at a handwritten problem. The AI doesn't just give the answer; it explains the logic step-by-step."
  },
  {
    q: "What are the subscription costs?",
    a: "You can start for free with basic features. Premium plans for advanced AI tools and unlimited multiplayer quizzes start at just KES 300 per week or KES 1000 per month."
  }
];

export default function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  const faqSchema = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: faqs.map((f) => ({
      '@type': 'Question',
      name: f.q,
      acceptedAnswer: {
        '@type': 'Answer',
        text: f.a,
      },
    })),
  };

  return (
    <section id="faq" className="py-24 bg-slate-50 relative overflow-hidden">
      <JsonLd data={faqSchema} />
      {/* Background decoration */}
      <div className="absolute top-1/2 left-0 -translate-x-1/2 -translate-y-1/2 w-64 h-64 bg-brand-primary/5 rounded-full blur-3xl pointer-events-none" />
      
      <motion.div 
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
        viewport={{ once: true, margin: "-100px" }}
        className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10"
      >
        <div className="text-center mb-16">
          <div className="inline-flex p-3 bg-brand-primary/10 text-brand-primary rounded-2xl mb-6">
            <HelpCircle className="w-6 h-6" />
          </div>
          <h2 className="text-sm font-bold text-brand-primary uppercase tracking-[0.25em] mb-4">Questions?</h2>
          <h3 className="text-4xl md:text-5xl lg:text-6xl font-display font-black text-slate-900 tracking-tighter leading-[1.05]">
            Everything you <br className="hidden md:block" /> need to know.
          </h3>
        </div>

        <div className="space-y-4">
          {faqs.map((faq, i) => (
            <motion.div
              key={i}
              initial={false}
              className={`border border-slate-200 rounded-3xl overflow-hidden transition-all ${openIndex === i ? 'bg-white shadow-xl shadow-indigo-50 border-brand-primary/20' : 'bg-white/50'}`}
            >
              <button
                onClick={() => setOpenIndex(openIndex === i ? null : i)}
                className="w-full px-8 py-6 text-left flex items-center justify-between gap-4"
              >
                <span className="font-display font-bold text-lg text-slate-900 tracking-tight">{faq.q}</span>
                <div className={`shrink-0 w-8 h-8 rounded-full flex items-center justify-center transition-colors ${openIndex === i ? 'bg-brand-primary text-white' : 'bg-slate-100 text-slate-500'}`}>
                  {openIndex === i ? <Minus className="w-4 h-4" /> : <Plus className="w-4 h-4" />}
                </div>
              </button>

              <AnimatePresence>
                {openIndex === i && (
                  <motion.div
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: 'auto', opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    transition={{ duration: 0.3 }}
                  >
                    <div className="px-8 pb-6 text-slate-600 leading-relaxed">
                      {faq.a}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.div>
          ))}
        </div>
      </motion.div>
    </section>
  );
}
