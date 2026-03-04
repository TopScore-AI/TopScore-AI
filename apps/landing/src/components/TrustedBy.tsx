'use client';
import AnimatedSection from './AnimatedSection';
import styles from './TrustedBy.module.css';

const metrics = [
    { value: '10,000+', label: 'Study Resources' },
    { value: '8', label: 'AI-Powered Tools' },
    { value: 'CBC & KCSE', label: 'Curricula Covered' },
    { value: '24/7', label: 'AI Tutor Access' },
];

const curricula = ['CBC (Grade 1–9)', '8-4-4 (KCSE)', 'IGCSE'];

export default function TrustedBy() {
    return (
        <section className={styles.section}>
            <AnimatedSection animation="fadeUp">
                <p className={styles.heading}>Trusted by students across Kenya</p>
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
