'use client';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './Personalization.module.css';
import { Calendar, Target, Activity, Brain } from 'lucide-react';

const personalFeatures = [
    { icon: <Calendar />, idx: 0, color: '#3b82f6' },
    { icon: <Target />, idx: 1, color: '#10b981' },
    { icon: <Activity />, idx: 2, color: '#f59e0b' },
    { icon: <Brain />, idx: 3, color: '#8b5cf6' },
];

export default function Personalization() {
    const { t } = useLocale();

    return (
        <section className={styles.wrapper}>
            <div className={styles.container}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('personal.label' as any)}</div>
                    <h2 className={styles.title}>{t('personal.title' as any)}</h2>
                    <p className={styles.sub}>{t('personal.sub' as any)}</p>
                </AnimatedSection>

                <div className={styles.grid}>
                    {personalFeatures.map((f) => (
                        <AnimatedSection 
                            key={f.idx} 
                            animation="fadeUp" 
                            delay={`${0.1 * f.idx}s`}
                            className={styles.card}
                        >
                            <div className={styles.iconWrapper} style={{ '--color': f.color } as any}>
                                {f.icon}
                            </div>
                            <h3 className={styles.cardTitle}>{t(`personal.${f.idx}.name` as any)}</h3>
                            <p className={styles.cardDesc}>{t(`personal.${f.idx}.desc` as any)}</p>
                        </AnimatedSection>
                    ))}
                </div>
            </div>
        </section>
    );
}
