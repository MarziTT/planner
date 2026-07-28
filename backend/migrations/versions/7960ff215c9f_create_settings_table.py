"""create settings table with weather_tone

Revision ID: 7960ff215c9f
Revises: a1b2c3d4e5f6
Create Date: 2026-07-27 18:29:57.582530

"""
from alembic import op
import sqlalchemy as sa


revision = '7960ff215c9f'
down_revision = 'a1b2c3d4e5f6'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('settings',
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), primary_key=True),
        sa.Column('theme', sa.String(length=32), nullable=False, server_default=sa.text("'forest'")),
        sa.Column('theme_mode', sa.String(length=16), nullable=False, server_default=sa.text("'dark'")),
        sa.Column('notifications_enabled', sa.Boolean(), nullable=False, server_default=sa.text('1')),
        sa.Column('voice_enabled', sa.Boolean(), nullable=False, server_default=sa.text('1')),
        sa.Column('update_channel', sa.String(length=32), nullable=False, server_default=sa.text("'stable'")),
        sa.Column('zzz_enabled', sa.Boolean(), nullable=False, server_default=sa.text('0')),
        sa.Column('weather_tone', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )


def downgrade():
    op.drop_table('settings')
