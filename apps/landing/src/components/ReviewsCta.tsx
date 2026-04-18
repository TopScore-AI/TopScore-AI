'use client';
import { useLocale } from '@/i18n';

export default function ReviewsCta() {
    const { t } = useLocale();
    
    return (
        <div className="mt-32 border-t border-white/5 pt-24 text-center flex flex-col items-center px-6">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 border border-primary/20 text-primary text-xs font-bold uppercase tracking-widest mb-8">
                {t('reviews.cta.label')}
            </div>
            <h2 className="text-4xl md:text-5xl font-black mb-8 tracking-tight text-center">{t('reviews.cta.title')}</h2>
            <p className="text-xl mb-12 max-w-2xl mx-auto leading-relaxed text-center" style={{ color: 'var(--text-muted)' }}>
                {t('reviews.cta.sub')}
            </p>
            <a href="/download" className="bg-primary text-white px-10 py-5 rounded-2xl font-black hover:scale-105 hover:shadow-[0_0_40px_rgba(37,99,235,0.3)] transition-all inline-block text-lg">
                Download Now Free
            </a>
        </div>
    );
}
