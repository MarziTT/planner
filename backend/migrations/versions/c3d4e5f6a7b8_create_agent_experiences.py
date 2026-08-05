"""create agent experiences

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-08-05 00:00:01.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = 'c3d4e5f6a7b8'
down_revision = 'b2c3d4e5f6a7'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'agent_experiences',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('source_text', sa.Text(), nullable=False, server_default=''),
        sa.Column('normalized_text', sa.String(length=240), nullable=False, server_default=''),
        sa.Column('intent', sa.String(length=40), nullable=False, server_default=''),
        sa.Column('parsed', sa.JSON().with_variant(postgresql.JSONB(), 'postgresql'), nullable=True),
        sa.Column('sample_count', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('last_used_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint('user_id', 'normalized_text', name='uq_agent_experience_text'),
    )
    op.create_index('ix_agent_experiences_user_id', 'agent_experiences', ['user_id'])
    op.create_index('ix_agent_experiences_normalized_text', 'agent_experiences', ['normalized_text'])
    op.create_index('ix_agent_experiences_intent', 'agent_experiences', ['intent'])


def downgrade():
    op.drop_index('ix_agent_experiences_intent', table_name='agent_experiences')
    op.drop_index('ix_agent_experiences_normalized_text', table_name='agent_experiences')
    op.drop_index('ix_agent_experiences_user_id', table_name='agent_experiences')
    op.drop_table('agent_experiences')
