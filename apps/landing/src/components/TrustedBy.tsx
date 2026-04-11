'use client';
import AnimatedSection from './AnimatedSection';
import styles from './TrustedBy.module.css';

const metrics = [
    { value: '100K+', label: 'Resources' },
    { value: 'CBC', label: 'Early Years - Grade 12' },
    { value: '8-4-4', label: 'Form 1 - Form 4' },
    { value: 'Cambridge', label: 'IGCSE' },
];

const curricula = ['CBC (Early Years - Grade 12)', '8-4-4 (Form 1 - Form 4)', 'Cambridge IGCSE'];

export default function TrustedBy() {
    return (
        <section className={styles.section}>
            <AnimatedSection animation="fadeUp">
                <p className={`${styles.heading} font-serif`}>Trusted by students across Kenya</p>
            </AnimatedSection>

            <AnimatedSection animation="fadeUp" delay="0.1s">
                <div className={styles.badges}>
                    {curricula.map((c) => (
                        <span key={c} className={styles.badge}>{c}</span>
                    ))}
                </div>
            </AnimatedSection>

            <AnimatedSection animation="fadeUp" delay="0.15s">
                <div className={styles.metrics}>
                    {metrics.map((m) => (
                        <div key={m.label} className={styles.metric}>
                            <strong>{m.value}</strong>
                            <span>{m.label}</span>
                        </div>
                    ))}
                </div>
            </AnimatedSection>
        </section>
    );
}
