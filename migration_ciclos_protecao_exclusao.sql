-- NAO APLICADA. Impede apagar um ciclo que tem respostas ou links de coleta.
-- Antes: ON DELETE SET NULL -> respostas/links ficavam com ciclo_id NULL em silencio e saiam de toda analise por ciclo.
-- NO ACTION (e nao RESTRICT) de proposito: a checagem roda ao FIM do comando, entao
-- excluirEmpresa() continua funcionando (o CASCADE de empresas apaga respostas/links junto com os ciclos).
-- Testado em DEV dentro de transacao revertida: ciclo com respostas bloqueia (23503),
-- ciclo vazio apaga, DELETE de empresa em cascata continua apagando.
-- laudos.ciclo_id fica SET NULL: o historico de laudos nao deve impedir a exclusao.
ALTER TABLE public.respostas     DROP CONSTRAINT respostas_ciclo_id_fkey;
ALTER TABLE public.respostas     ADD  CONSTRAINT respostas_ciclo_id_fkey
  FOREIGN KEY (ciclo_id) REFERENCES public.ciclos(id) ON DELETE NO ACTION;
ALTER TABLE public.links_coleta  DROP CONSTRAINT links_coleta_ciclo_id_fkey;
ALTER TABLE public.links_coleta  ADD  CONSTRAINT links_coleta_ciclo_id_fkey
  FOREIGN KEY (ciclo_id) REFERENCES public.ciclos(id) ON DELETE NO ACTION;
