'use client';
import { useState, useEffect } from 'react';
import { collection, query, where, orderBy, limit, getDocs } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import FeedbackModal from './FeedbackModal';
import { MessageSquarePlus } from "lucide-react";
import styles from './Testimonials.module.css';

interface Testimonial {
    id: string;
    name: string;
    rating: number;
    text: string;
    avatar?: string;
    role?: string;
}

const fallbackAvatars = ['👩🏾‍🎓', '👨🏾‍🏫', '👩🏾', '👦🏾', '🧑🏾‍💻', '👩🏾‍🔬'];

export default function Testimonials() {
    const { t } = useLocale();
    const [testimonials, setTestimonials] = useState<Testimonial[]>([]);
    const [isModalOpen, setIsModalOpen] = useState(false);

    useEffect(() => {
        const fetchTestimonials = async () => {
            try {
                const q = query(
                    collection(db, "testimonials"),
                    where("approved", "==", true),
                    orderBy("createdAt", "desc"),
                    limit(6)
                );
                const querySnapshot = await getDocs(q);
                const fetched = querySnapshot.docs.map(doc => ({
                    id: doc.id,
                    ...doc.data()
                })) as Testimonial[];

                if (fetched.length > 0) {
                    setTestimonials(fetched);
                } else {
                    setTestimonials([
                        { id: '1', name: t('testimonials.0.name' as any), rating: 5, text: t('testimonials.0.quote' as any), role: t('testimonials.0.role' as any), avatar: '👩🏾‍🎓' },
                        { id: '2', name: t('testimonials.1.name' as any), rating: 5, text: t('testimonials.1.quote' as any), role: t('testimonials.1.role' as any), avatar: '👨🏾‍🏫' },
                        { id: '3', name: t('testimonials.2.name' as any), rating: 5, text: t('testimonials.2.quote' as any), role: t('testimonials.2.role' as any), avatar: '👩🏾' },
                    ]);
                }
            } catch (error) {
                console.error("Error fetching testimonials:", error);
            }
        };

        fetchTestimonials();
    }, [t]);

    return (
        <section className={styles.wrapper} id="testimonials">
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.header}>
                        <div className={styles.label}>{t('testimonials.label' as any)}</div>
                        <h2 className={styles.title}>{t('testimonials.title' as any)}</h2>
                        <button 
                            onClick={() => setIsModalOpen(true)}
                            className={styles.submitBtn}
                        >
                            <MessageSquarePlus size={18} />
                            {t('testimonials.submit' as any)}
                        </button>
                    </div>
                </AnimatedSection>

                <div className={styles.grid}>
                    {testimonials.map((testimonial, i) => (
                        <AnimatedSection key={testimonial.id} animation="fadeUp" delay={`${i * 0.1}s`}>
                            <div className={styles.card}>
                                <div className={styles.stars}>
                                    {Array.from({ length: 5 }).map((_, starIdx) => (
                                        <span key={starIdx}>
                                            {starIdx < testimonial.rating ? '★' : '☆'}
                                        </span>
                                    ))}
                                </div>
                                <p className={styles.quote}>&ldquo;{testimonial.text}&rdquo;</p>
                                <div className={styles.person}>
                                    <div className={styles.avatar}>
                                        {testimonial.avatar || fallbackAvatars[i % fallbackAvatars.length]}
                                    </div>
                                    <div className={styles.info}>
                                        <span className={styles.name}>{testimonial.name}</span>
                                        <span className={styles.role}>{testimonial.role || "Verified Student"}</span>
                                    </div>
                                </div>
                            </div>
                        </AnimatedSection>
                    ))}
                </div>
            </div>

            <FeedbackModal 
                isOpen={isModalOpen} 
                onClose={() => setIsModalOpen(false)} 
            />
        </section>
    );
}
