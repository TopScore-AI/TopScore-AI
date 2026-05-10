'use client';
import { motion } from 'framer-motion';
import { Quote } from 'lucide-react';

const testimonials = [
  {
    quote: "TopScore AI turned my Biology grades around. The Gemini Live feature feels like having a personal tutor who never gets tired of my questions.",
    author: "Faith W.",
    role: "Form 4 Student, Alliance Girls",
    avatar: "https://picsum.photos/seed/faith/100/100"
  },
  {
    quote: "As an IGCSE student, finding local resources that match international standards is hard. TopScore bridges that gap perfectly.",
    author: "Kevin O.",
    role: "Year 11, St. Austin's Academy",
    avatar: "https://picsum.photos/seed/kevin/100/100"
  },
  {
    quote: "The CBE support and ability to summarize complex CBC topics into simple diagrams has made my daughter much more confident in class.",
    author: "Mrs. Kamau",
    role: "Parent, Nairobi",
    avatar: "https://picsum.photos/seed/kamau/100/100"
  }
];

export default function Testimonials() {
  return (
    <section id="testimonials" className="py-24 bg-white">
      <motion.div 
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
        viewport={{ once: true, margin: "-100px" }}
        className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-10"
      >
        <div className="text-center mb-16">
          <h2 className="text-sm font-bold text-brand-primary uppercase tracking-[0.25em] mb-4">Social Proof</h2>
          <h3 className="text-3xl md:text-5xl font-sans font-extrabold text-slate-900 tracking-tight">Trusted by Scholars</h3>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          {testimonials.map((t, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, scale: 0.95 }}
              whileInView={{ opacity: 1, scale: 1 }}
              transition={{ duration: 0.5, delay: i * 0.1 }}
              viewport={{ once: true }}
              className="bg-slate-50 p-8 rounded-[2.5rem] border border-slate-100 flex flex-col justify-between group hover:bg-white hover:shadow-2xl hover:shadow-indigo-100 transition-all duration-500"
            >
              <div>
                <Quote className="w-10 h-10 text-brand-primary/20 mb-6 group-hover:text-brand-primary/40 transition-colors" />
                <p className="text-slate-600 text-lg leading-relaxed italic mb-8">"{t.quote}"</p>
              </div>
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full overflow-hidden border-2 border-white shadow-sm">
                  <img src={t.avatar} alt={t.author} className="w-full h-full object-cover" />
                </div>
                <div>
                  <h4 className="font-bold text-slate-900 leading-tight">{t.author}</h4>
                  <p className="text-xs font-medium text-slate-500">{t.role}</p>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </motion.div>
    </section>
  );
}
