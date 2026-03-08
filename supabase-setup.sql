-- ============================================
-- Supabase 익명 댓글 시스템 - 테이블 생성 및 RLS 정책
-- ============================================

-- 1. 댓글 테이블 생성
CREATE TABLE comments (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  page_slug  TEXT NOT NULL,
  nickname   TEXT NOT NULL CHECK (char_length(nickname) BETWEEN 1 AND 30),
  content    TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 1000),
  parent_id  UUID REFERENCES comments(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. 인덱스 (페이지별 댓글 조회 성능 향상)
CREATE INDEX idx_comments_page_slug ON comments(page_slug);
CREATE INDEX idx_comments_parent_id ON comments(parent_id);

-- 3. Row Level Security 활성화
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- 4. RLS 정책: 누구나 조회 가능
CREATE POLICY "Anyone can read comments"
  ON comments FOR SELECT
  USING (true);

-- 5. RLS 정책: 누구나 삽입 가능
CREATE POLICY "Anyone can insert comments"
  ON comments FOR INSERT
  WITH CHECK (true);

-- UPDATE, DELETE 정책은 생성하지 않으므로 익명 사용자는 수정/삭제 불가


-- ============================================
-- 좋아요/싫어요 리액션 시스템
-- ============================================

-- 6. 리액션 테이블 생성
CREATE TABLE reactions (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  page_slug  TEXT NOT NULL,
  type       TEXT NOT NULL CHECK (type IN ('like', 'dislike')),
  voter_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(page_slug, voter_hash)
);

-- 7. 인덱스 (페이지별 리액션 조회 성능 향상)
CREATE INDEX idx_reactions_page_slug ON reactions(page_slug);

-- 8. Row Level Security 활성화
ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;

-- 9. RLS 정책: 누구나 조회 가능
CREATE POLICY "Anyone can read reactions"
  ON reactions FOR SELECT
  USING (true);

-- 10. RLS 정책: 누구나 삽입 가능
CREATE POLICY "Anyone can insert reactions"
  ON reactions FOR INSERT
  WITH CHECK (true);

-- UPDATE, DELETE 정책은 생성하지 않으므로 한 번 투표하면 변경/삭제 불가
