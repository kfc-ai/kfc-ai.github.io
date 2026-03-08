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

-- UPDATE, DELETE는 RPC 함수(SECURITY DEFINER)가 처리하므로 직접 정책 불필요

-- ============================================
-- 리액션 토글 RPC 함수 (투표 취소/변경 지원)
-- ============================================

-- 11. toggle_reaction 함수
-- 동작: 없으면 INSERT, 같은 타입이면 DELETE(취소), 다른 타입이면 UPDATE(변경)
CREATE OR REPLACE FUNCTION toggle_reaction(
  p_page_slug TEXT,
  p_type TEXT,
  p_voter_hash TEXT
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  existing RECORD;
BEGIN
  SELECT * INTO existing FROM reactions
  WHERE page_slug = p_page_slug AND voter_hash = p_voter_hash;

  IF existing IS NULL THEN
    INSERT INTO reactions (page_slug, type, voter_hash)
    VALUES (p_page_slug, p_type, p_voter_hash);
    RETURN json_build_object('action', 'inserted', 'type', p_type);
  ELSIF existing.type = p_type THEN
    DELETE FROM reactions WHERE id = existing.id;
    RETURN json_build_object('action', 'deleted', 'type', NULL);
  ELSE
    UPDATE reactions SET type = p_type WHERE id = existing.id;
    RETURN json_build_object('action', 'updated', 'type', p_type);
  END IF;
END;
$$;

-- 12. anon 역할에 실행 권한 부여
GRANT EXECUTE ON FUNCTION toggle_reaction(TEXT, TEXT, TEXT) TO anon;
