'use client';
import AnimatedSection from './AnimatedSection';
import { Button } from '@/components/ui/button';
import { Mail, MessageCircle, MapPin } from 'lucide-react';
import styles from './Contact.module.css';

export default function Contact() {
    return (
        <section className={styles.contact} id="contact">
            <div className={styles.container}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.header}>
                        <h2 className={styles.title}>Get in Touch</h2>
                        <p className={styles.subtitle}>Have questions or need help? We're here for you.</p>
                    </div>
                </AnimatedSection>

                <div className={styles.content}>
                    <AnimatedSection animation="fadeRight" delay="0.1s">
                        <div className={styles.infoBox}>
                            <h3 className={styles.infoTitle}>Contact Information</h3>
                            <p className={styles.infoText}>Reach out to us directly through any of these channels.</p>
                            
                            <div className={styles.contactMethods}>
                                <div className={styles.method}>
                                    <div className={styles.iconWrapper}>
                                        <Mail className={styles.icon} size={24} />
                                    </div>
                                    <div>
                                        <p className={styles.methodLabel}>Email</p>
                                        <a href="mailto:support@topscoreapp.ai" className={styles.methodLink}>support@topscoreapp.ai</a>
                                    </div>
                                </div>
                                <div className={styles.method}>
                                    <div className={styles.iconWrapper}>
                                        <MessageCircle className={styles.icon} size={24} />
                                    </div>
                                    <div>
                                        <p className={styles.methodLabel}>WhatsApp Support</p>
                                        <a href="https://wa.me/254700000000" className={styles.methodLink}>+254 700 000 000</a>
                                    </div>
                                </div>
                                <div className={styles.method}>
                                    <div className={styles.iconWrapper}>
                                        <MapPin className={styles.icon} size={24} />
                                    </div>
                                    <div>
                                        <p className={styles.methodLabel}>Location</p>
                                        <p className={styles.methodText}>Nairobi, Kenya</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </AnimatedSection>

                    <AnimatedSection animation="fadeLeft" delay="0.2s">
                        <form className={styles.form} onSubmit={(e) => e.preventDefault()}>
                            <div className={styles.formGroup}>
                                <label htmlFor="name" className={styles.label}>Name</label>
                                <input type="text" id="name" className={styles.input} placeholder="Your Name" required />
                            </div>
                            <div className={styles.formGroup}>
                                <label htmlFor="email" className={styles.label}>Email</label>
                                <input type="email" id="email" className={styles.input} placeholder="you@example.com" required />
                            </div>
                            <div className={styles.formGroup}>
                                <label htmlFor="message" className={styles.label}>Message</label>
                                <textarea id="message" className={styles.textarea} placeholder="How can we help?" rows={4} required></textarea>
                            </div>
                            <Button type="submit" size="lg" className={styles.submitBtn}>
                                Send Message
                            </Button>
                        </form>
                    </AnimatedSection>
                </div>
            </div>
        </section>
    );
}