'use client';
import { motion } from 'framer-motion';
import { useLocale } from '@/i18n';
import Image from 'next/image';
import { Smartphone, BookOpen, LayoutDashboard, LogIn } from 'lucide-react';

const screenshots = [
  { id: 1, title: "Secure Login", desc: "Access your personalized portal", color: "bg-blue-600", icon: <LogIn className="w-6 h-6" /> },
  { id: 2, title: "AI Tutor Chat", desc: "Real-time 1-on-1 tutoring", color: "bg-indigo-500", icon: <Smartphone className="w-6 h-6" /> },
  { id: 3, title: "Smart Library", desc: "100,000+ revision resources", color: "bg-emerald-500", icon: <BookOpen className="w-6 h-6" /> },
  { id: 4, title: "Student Dashboard", desc: "Track your progress & rankings", color: "bg-amber-500", icon: <LayoutDashboard className="w-6 h-6" /> }
];

export default function Screenshots() {
  const { t } = useLocale();

  return (
    <section className="py-24 bg-slate-50 rounded-[3.5rem] mx-4 sm:mx-10 overflow-hidden">
      <div className="max-w-7xl mx-auto px-4 sm:px-10">
        <div className="text-center max-w-3xl mx-auto mb-20">
            <h2 className="text-sm font-bold text-brand-primary uppercase tracking-[0.25em] mb-6">Visual Showcase</h2>
            <h3 className="text-4xl md:text-5xl lg:text-6xl font-display font-black text-slate-900 tracking-tighter leading-[1.05] mb-8">
                A premium interface <br className="hidden md:block" /> for elite scholars.
            </h3>
            <p className="text-slate-600 text-lg leading-relaxed font-bold max-w-xl mx-auto">
                Every screen is meticulously designed to minimize distraction and maximize cognitive focus for the best learning experience.
            </p>
        </div>


        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
          {screenshots.map((s, i) => (
            <motion.div
              key={s.id}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6, delay: i * 0.1, ease: "easeOut" }}
              viewport={{ once: true, margin: "-50px" }}
              className="group"
            >
              <div className="relative aspect-[9/19] bg-slate-900 rounded-[2.5rem] p-3 shadow-2xl border border-slate-200 mb-8 overflow-hidden group-hover:-translate-y-4 transition-transform duration-700 ease-out">
                  <div className="absolute inset-0 bg-gradient-to-b from-indigo-500/10 to-transparent z-10 pointer-events-none" />
                  <div className="bg-white rounded-[2rem] h-full w-full overflow-hidden relative border border-slate-800/10">
                      <Image 
                        src={`/screenshots/screen-${i}.png`} 
                        alt={s.title}
                        fill
                        className="object-cover group-hover:scale-110 transition-transform duration-700 ease-out"
                        sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 25vw"
                        priority={i < 2}
                      />
                      <div className="absolute inset-0 bg-slate-900/5 group-hover:bg-transparent transition-colors duration-500" />
                  </div>
              </div>
              <div className="space-y-3 px-2">
                  <div className="flex items-center gap-3">
                      <div className={`${s.color} w-10 h-10 rounded-xl flex items-center justify-center text-white shadow-lg shadow-current/20 group-hover:scale-110 transition-transform`}>
                          {s.icon}
                      </div>
                      <h4 className="text-lg font-bold text-slate-900 tracking-tight">{s.title}</h4>
                  </div>
                  <p className="text-sm text-slate-500 font-medium ml-13 leading-snug">{s.desc}</p>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
