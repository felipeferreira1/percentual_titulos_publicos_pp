#Rotina para coletar e calcular o percentual de t�tulos p�blicos em poder do p�blico 
#Feito por: Felipe Simpl�cio Ferreira
#�ltima atualiza��o: 13/11/2019

#Definindo diret�rios a serem utilizados
getwd()
setwd("C:/Users/User/Documents")

#Carregando pacotes que ser�o utilizados
library(tidyverse)
library(data.table)
library(RQuantLib)
library(zoo)
library(rio)
library(lubridate)
library(ggplot2)
library(scales)
library(ggrepel)

#Definindo argumentos da coleta
abertura = "D" #D (dia) ou M (m�s) ou A (ano)
indice = "M" #M para valores em R$ milh�es, R para valores em Reais, S para valores US$ milh�es ou U para valores em US$ 
formato = "A" #A (CSV) ou T (tela) ou E (Excel)
data_inicial = "2020-01-01" %>% as.Date()
data_final = as.Date(Sys.time())

#Criando lista com �ltimos dias �teis do m�s
lista_dias <- c(data_inicial, data_final) #Lista com data do in�cio do ano e data de hoje
dias_uteis <- seq(lista_dias[1], lista_dias[2], by="1 day") #Calculando quais s�o os dias entre essas duas datas 
dias_uteis <- data.frame(dates=dias_uteis, bizday=isBusinessDay("Brazil", dias_uteis)) #Marcando quais desses dias s�o �teis
dias_uteis <- filter(dias_uteis, bizday == "TRUE") #Filtrando s� os dias �teis
dias_uteis <- data.table(dias_uteis) #Transformando em data.table
dias_uteis <- dias_uteis %>% mutate(lista_dias = tapply(dias_uteis$dates, as.yearmon(dias_uteis$dates))) #Criando coluna com a lista_dias

#Como a refer�ncia de um m�s � o �ltimo dia �til do m�s anterior, vamos pegar todo primeiro dia �tel dos meses (para identificar) e o �ltimo dia �til do m�s anterior(para ser a refer�ncia na busca) de cada m�s
ultimo_dia_util <- dias_uteis[,tail(.SD,1),by = lista_dias] #Selecionando o �ltimo dia �til de cada m�s
ultimo_dia_util <- as.array(ultimo_dia_util$dates) #Transformando em vetor
ultimo_dia_util[length(ultimo_dia_util)] <- format(Sys.time()) #Adicionando dia de hoje
ultimo_dia_util <- format(ultimo_dia_util, "%d/%m/%Y") #Formatando como datas "dd/mm/YYYY"
primeiro_dia_util <- dias_uteis[,head(.SD,1),by = lista_dias] #Selecionando o primeiro dia �til de cada m�s
primeiro_dia_util <- as.array(primeiro_dia_util$dates) #Transformando em vetor
dia_do_ultimo_dado <- as.Date(Sys.Date()) #Pegamos o dia do �ltimo dado, sabendo que a refer�ncia sempre ser� o dia �til imediatamente anterior
while (isBusinessDay("Brazil", dia_do_ultimo_dado) == F)
  dia_do_ultimo_dado <- dia_do_ultimo_dado + 1
primeiro_dia_util[length(primeiro_dia_util) + 1 ] <- dia_do_ultimo_dado
primeiro_dia_util <- primeiro_dia_util[-1] #Tirando primeiro dado, j� que a refer�ncia do 1� m�s da da s�rie � calculada tendo como refer�ncia o �ltimo dia �til do m�s anterior
primeiro_dia_util <- format(primeiro_dia_util, "%d/%m/%Y") #Formatando como datas "dd/mm/YYYY"

#Criando lista com nome de arquivos
lista_nome_arquivos <- NULL #Vazia, a ser preenchida

#Coleta de dados
for (i in 1:length(ultimo_dia_util)){
  dados <- read.csv(url(paste("http://www4.bcb.gov.br/pom/demab/cronograma/vencdata_csv.asp?data=", ultimo_dia_util[i], "&abertura=", abertura, "&indice=", indice, "&formato=", formato, sep="")),sep=";", skip = 3)
  dados <- data.table(dados) #Transformando em data table para facilitar as manipula��es
  dados <- select(dados, Data = VENCIMENTO, Total = TOTAL, Participa��o = PART..) #Selecionando as colunas que vamos usar
  dados$Data <- as.Date(dados$Data, "%d/%m/%Y") #Transformando a coluna de data em data
  dados <- transform(dados, Total = as.numeric(gsub(",",".",Total))) #Transformando o resto das colunas em n�meros
  dados <- transform(dados, `Participa��o` = as.numeric(gsub(",",".",`Participa��o`))) #Transformando o resto das colunas em n�meros
  nome_arquivo <- paste("Ref_", gsub("/", "_", ultimo_dia_util[i]), sep = "") #Nomeia os v�rios arquivos intermedi�rios que s�o criados com cada s�rie
  assign(nome_arquivo, dados) #Nomeando arquivos
  lista_nome_arquivos[i] <- nome_arquivo #Guardando nome dos arquivos
  if(i==1)
    export(dados, "Percentual - T�tulos P�blicos em Poder do P�blico(fonte).xlsx", sheetName = nome_arquivo)
  else
    export(dados, "Percentual - T�tulos P�blicos em Poder do P�blico(fonte).xlsx", which = nome_arquivo)
  print(paste(i, length(ultimo_dia_util), sep = '/')) #Printa o progresso da repeti��o
}
rm(dados)

#Calculando acumulados em 6 e 12 meses
filtros_6_meses <- ymd(as.Date(ultimo_dia_util, format = "%d/%m/%Y") %m+% months(6)) #Calculando 6 meses a frente
filtros_12_meses <- ymd(as.Date(ultimo_dia_util, format = "%d/%m/%Y") %m+% months(12)) #Calculando 12 meses a frente
acumulado_6_meses <- data.table(Data = as.Date(primeiro_dia_util, format = "%d/%m/%Y"), Acumulado = 0) #Criando data.table vazio
acumulado_12_meses <- data.table(Data = as.Date(primeiro_dia_util, format = "%d/%m/%Y"), Acumulado = 0) #Criando data.table vazio

for (i in 1:length(lista_nome_arquivos)){
  acumulado <- get(lista_nome_arquivos[i]) #Chamando arquivos
  acumulado <- filter(acumulado, Data < filtros_6_meses[i]) #Filtrando para datas < que 6 meses
  acumulado <- sum(acumulado$Participa��o) #Calculando o acumulado p�s-filtro
  acumulado_6_meses[i,2] <- acumulado #Adicionando ao data.table de acumulados
  print(paste(i, length(lista_nome_arquivos), sep = '/')) #Printa o progresso da repeti��o
}

export(acumulado_6_meses, "Percentual - T�tulos P�blicos em Poder do P�blico(fonte).xlsx", which = "Acum_6_meses")

for (i in 1:length(lista_nome_arquivos)){
  acumulado <- get(lista_nome_arquivos[i]) #Chamando arquivos
  acumulado <- filter(acumulado, Data < filtros_12_meses[i]) #Filtrando para datas < que 12 meses
  acumulado <- sum(acumulado$Participa��o) #Calculando o acumulado p�s-filtro
  acumulado_12_meses[i,2] <- acumulado #Adicionando ao data.table de acumulados
  print(paste(i, length(lista_nome_arquivos), sep = '/')) #Printa o progresso da repeti��o
}

export(acumulado_12_meses, "Percentual - T�tulos P�blicos em Poder do P�blico(fonte).xlsx", which = "Acum_12_meses")

#Gr�ficos
  #Acumulado em 6 meses
graf_acum_6_meses <- ggplot(acumulado_6_meses, aes(x = Data, y = Acumulado)) + geom_bar(stat = "identity", fill = "darkblue") + 
  geom_label_repel(aes(label = sprintf("%0.2f", round(Acumulado,2))), force = 0.01) + 
  theme_minimal() + scale_x_date(breaks = date_breaks("1 month"), labels = date_format("%d/%b")) + 
  theme(axis.text.x=element_text(angle=45, hjust=1)) + xlab("") + ylab("") + 
  labs(title = "Vencimento de T�tulos Federais em Poder do P�blico", subtitle = "Percentual da D�vida Total vencendo em at� 6 meses",
       caption = "Fonte: BCB")

ggsave("acumulado_6_meses.png", graf_acum_6_meses)
       
graf_acum_12_meses <- ggplot(acumulado_12_meses, aes(x = Data, y = Acumulado)) + geom_bar(stat = "identity", fill = "darkblue") + 
  geom_label_repel(aes(label = sprintf("%0.2f", round(Acumulado,2))), force = 0.01) + 
  theme_minimal() + scale_x_date(breaks = date_breaks("1 month"), labels = date_format("%d/%b")) + 
  theme(axis.text.x=element_text(angle=45, hjust=1)) + xlab("") + ylab("") + 
  labs(title = "Vencimento de T�tulos Federais em Poder do P�blico", subtitle = "Percentual da D�vida Total vencendo em at� 12 meses",
       caption = "Fonte: BCB")

ggsave("acumulado_12_meses.png", graf_acum_12_meses)