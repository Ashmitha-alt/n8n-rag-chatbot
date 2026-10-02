-- Supabase setup for the n8n RAG chatbot
-- Run this once in the Supabase SQL editor before running the ingestion workflow.

-- 1. Enable pgvector
create extension if not exists vector;

-- 2. Table that stores document chunks and their embeddings.
--    768 = output size of n8n's default HuggingFace embedding model
--    (sentence-transformers/distilbert-base-nli-mean-tokens).
--    Change it if you pick a different embedding model.
create table if not exists documents (
  id bigserial primary key,
  content text,
  metadata jsonb,
  embedding vector(768)
);

-- 3. Similarity search function used by the Supabase Vector Store node
create or replace function match_documents (
  query_embedding vector(768),
  match_count int default null,
  filter jsonb default '{}'
) returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
#variable_conflict use_column
begin
  return query
  select
    id,
    content,
    metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;
