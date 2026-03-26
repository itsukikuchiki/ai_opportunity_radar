import { pgTable, text, timestamp, boolean } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: text('id').primaryKey(),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).defaultNow().notNull(),
});

export const userProfiles = pgTable('user_profiles', {
  userId: text('user_id').primaryKey().references(() => users.id, { onDelete: 'cascade' }),
  selectedRepeatArea: text('selected_repeat_area'),
  selectedAiHelpType: text('selected_ai_help_type'),
  selectedOutputPreference: text('selected_output_preference'),
  onboardingCompleted: boolean('onboarding_completed').default(false).notNull(),
});
