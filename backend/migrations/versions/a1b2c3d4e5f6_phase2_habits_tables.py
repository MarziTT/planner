"""phase2_habits_tables

Revision ID: a1b2c3d4e5f6
Revises: cf743d733813
Create Date: 2026-07-23 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a1b2c3d4e5f6'
down_revision = 'cf743d733813'
branch_labels = None
depends_on = None


def upgrade():
    # ----------------------------------------------------------------
    #  1. event_history
    # ----------------------------------------------------------------
    op.create_table('event_history',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('event_id', sa.Integer(), nullable=True),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('notify_type', sa.String(length=50), nullable=False),
        sa.Column('planned_time', sa.DateTime(), nullable=False),
        sa.Column('reminded_at', sa.DateTime(), nullable=True),
        sa.Column('completed_at', sa.DateTime(), nullable=True),
        sa.Column('delayed_count', sa.Integer(), nullable=False,
                  server_default=sa.text('0')),
        sa.Column('skipped', sa.Boolean(), nullable=False,
                  server_default=sa.text('0')),
        sa.Column('created_at', sa.DateTime(), nullable=False,
                  server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['event_id'], ['events.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
    )
    with op.batch_alter_table('event_history', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_event_history_event_id'),
                              ['event_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_event_history_user_id'),
                              ['user_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_event_history_notify_type'),
                              ['notify_type'], unique=False)

    # ----------------------------------------------------------------
    #  2. user_patterns
    # ----------------------------------------------------------------
    op.create_table('user_patterns',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('pattern_type', sa.String(length=50), nullable=False),
        sa.Column('pattern_key', sa.String(length=100), nullable=False,
                  server_default=sa.text("''")),
        sa.Column('pattern_value', sa.Text(), nullable=True),
        sa.Column('confidence', sa.Float(), nullable=False,
                  server_default=sa.text('0.0')),
        sa.Column('sample_count', sa.Integer(), nullable=False,
                  server_default=sa.text('0')),
        sa.Column('created_at', sa.DateTime(), nullable=False,
                  server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False,
                  server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'pattern_type', 'pattern_key',
                            name='uq_user_pattern'),
    )
    with op.batch_alter_table('user_patterns', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_user_patterns_user_id'),
                              ['user_id'], unique=False)

    # ----------------------------------------------------------------
    #  3. notify_preferences
    # ----------------------------------------------------------------
    op.create_table('notify_preferences',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('notify_type', sa.String(length=50), nullable=False),
        sa.Column('lead_minutes', sa.Integer(), nullable=True),
        sa.Column('enabled', sa.Boolean(), nullable=False,
                  server_default=sa.text('1')),
        sa.Column('quiet_hours_start', sa.Time(), nullable=True),
        sa.Column('quiet_hours_end', sa.Time(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False,
                  server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False,
                  server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'notify_type', name='uq_notify_pref'),
    )
    with op.batch_alter_table('notify_preferences', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_notify_preferences_user_id'),
                              ['user_id'], unique=False)

    # ----------------------------------------------------------------
    #  4. ocr_cache
    # ----------------------------------------------------------------
    op.create_table('ocr_cache',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('image_hash', sa.String(length=64), nullable=False),
        sa.Column('raw_text', sa.Text(), nullable=False,
                  server_default=sa.text("''")),
        sa.Column('parsed', sa.Text(), nullable=True),
        sa.Column('processed_at', sa.DateTime(), nullable=False,
                  server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'image_hash', name='uq_ocr_cache_hash'),
    )
    with op.batch_alter_table('ocr_cache', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_ocr_cache_user_id'),
                              ['user_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_ocr_cache_image_hash'),
                              ['image_hash'], unique=False)

    # ----------------------------------------------------------------
    #  5. meal_records
    # ----------------------------------------------------------------
    op.create_table('meal_records',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('meal_type', sa.String(length=20), nullable=False),
        sa.Column('items', sa.Text(), nullable=True),
        sa.Column('recorded_at', sa.DateTime(), nullable=False,
                  server_default=sa.func.now()),
        sa.Column('source', sa.String(length=20), nullable=False,
                  server_default=sa.text("'photo'")),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
    )
    with op.batch_alter_table('meal_records', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_meal_records_user_id'),
                              ['user_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_meal_records_recorded_at'),
                              ['recorded_at'], unique=False)

    # ----------------------------------------------------------------
    #  6. exercise_records
    # ----------------------------------------------------------------
    op.create_table('exercise_records',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('exercise_type', sa.String(length=50), nullable=False),
        sa.Column('duration_minutes', sa.Integer(), nullable=False,
                  server_default=sa.text('0')),
        sa.Column('recorded_at', sa.DateTime(), nullable=False,
                  server_default=sa.func.now()),
        sa.Column('source', sa.String(length=20), nullable=False,
                  server_default=sa.text("'auto'")),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
    )
    with op.batch_alter_table('exercise_records', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_exercise_records_user_id'),
                              ['user_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_exercise_records_recorded_at'),
                              ['recorded_at'], unique=False)

    # ----------------------------------------------------------------
    #  7. users — add Phase 2 columns
    # ----------------------------------------------------------------
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column(
            'exercise_mode', sa.String(length=20), nullable=False,
            server_default=sa.text("'self'"),
        ))
        batch_op.add_column(sa.Column(
            'trainer_end_date', sa.Date(), nullable=True,
        ))


def downgrade():
    # ----------------------------------------------------------------
    #  Remove Phase 2 users columns
    # ----------------------------------------------------------------
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('trainer_end_date')
        batch_op.drop_column('exercise_mode')

    # ----------------------------------------------------------------
    #  Drop tables in reverse order
    # ----------------------------------------------------------------
    with op.batch_alter_table('exercise_records', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_exercise_records_recorded_at'))
        batch_op.drop_index(batch_op.f('ix_exercise_records_user_id'))
    op.drop_table('exercise_records')

    with op.batch_alter_table('meal_records', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_meal_records_recorded_at'))
        batch_op.drop_index(batch_op.f('ix_meal_records_user_id'))
    op.drop_table('meal_records')

    with op.batch_alter_table('ocr_cache', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_ocr_cache_image_hash'))
        batch_op.drop_index(batch_op.f('ix_ocr_cache_user_id'))
    op.drop_table('ocr_cache')

    with op.batch_alter_table('notify_preferences', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_notify_preferences_user_id'))
    op.drop_table('notify_preferences')

    with op.batch_alter_table('user_patterns', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_user_patterns_user_id'))
    op.drop_table('user_patterns')

    with op.batch_alter_table('event_history', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_event_history_notify_type'))
        batch_op.drop_index(batch_op.f('ix_event_history_user_id'))
        batch_op.drop_index(batch_op.f('ix_event_history_event_id'))
    op.drop_table('event_history')
