'use client';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Mic, Eye, Zap, Waves, Scan, Radio } from 'lucide-react';
import styles from './ActiveVoiceShowcase.module.css';

const features = [
    { icon: <Eye />, key: 'multimodalShowcase.features.0', color: '#3b82f6' },
    { icon: <Zap />, key: 'multimodalShowcase.features.1', color: '#f59e0b' },
    { icon: <Mic />, key: 'multimodalShowcase.features.2', color: '#10b981' },
];

export default function ActiveVoiceShowcase() {
    const { t } = useLocale();

    return (
        <section className={styles.section} id="multimodal">
            <div className={styles.container}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.header}>
                        <div className={styles.label}>
                            <Radio size={14} className={styles.liveIcon} />
                            {t('multimodalShowcase.label' as any)}
                        </div>
                        <h2 className={styles.title}>{t('multimodalShowcase.title' as any)}</h2>
                        <p className={styles.sub}>{t('multimodalShowcase.sub' as any)}</p>
                    </div>
                </AnimatedSection>

                <div className={styles.grid}>
                    <div className={styles.visualSide}>
                        <AnimatedSection animation="fadeUp" delay="0.2s">
                            <div className={styles.visualContainer}>
                                <div className={styles.glow} />
                                
                                {/* Visual Intelligence Sphere */}
                                <div className={styles.sightSphere}>
                                    <div className={styles.scannerLine} />
                                    <Scan className={styles.innerScanIcon} size={48} />
                                    <div className={styles.particle} style={{'--top': '20%', '--left': '30%', '--delay': '0s'} as any} />
                                    <div className={styles.particle} style={{'--top': '60%', '--left': '75%', '--delay': '1.5s'} as any} />
                                    <div className={styles.particle} style={{'--top': '80%', '--left': '20%', '--delay': '0.8s'} as any} />
                                </div>

                                {/* Audio Waveforms */}
                                <div className={styles.waveWrapper}>
                                    {[...Array(24)].map((_, i) => (
                                        <div 
                                            key={i} 
                                            className={styles.waveBar} 
                                            style={{ 
                                                '--delay': `${i * 0.05}s`, 
                                                '--height': `${15 + Math.sin(i * 0.5) * 40 + (i % 3) * 10}%` 
                                            } as any} 
                                        />
                                    ))}
                                </div>

                                <div className={styles.status}>
                                    <div className={styles.pulse} />
                                    <span>TopScore Real-Time™ Active</span>
                                </div>
                            </div>
                        </AnimatedSection>
                    </div>

                    <div className={styles.textSide}>
                        {features.map((f, i) => (
                            <AnimatedSection key={f.key} animation="fadeUp" delay={`${0.3 + i * 0.1}s`}>
                                <div className={styles.item}>
                                    <div className={styles.iconWrapper} style={{ '--color': f.color } as any}>
                                        {f.icon}
                                    </div>
                                    <div className={styles.itemContent}>
                                        <h3 className={styles.itemName}>{t(`${f.key}.name` as any)}</h3>
                                        <p className={styles.itemDesc}>{t(`${f.key}.desc` as any)}</p>
                                    </div>
                                </div>
                            </AnimatedSection>
                        ))}
                    </div>
                </div>
            </div>
        </section>
    );
}
