library(ggplot2)
library(RColorBrewer)
library(rpart)
library(C50)
library(pROC)
library(randomForest)
library(cluster)
library(reshape2)
library(plotly)

# 1. Importe e trate o dataset
wine <- read.csv("C:/Users/jaynn/Documents/Cursos/Curso-cesae/R/ProjetoFinal/wine.csv")

# 2. Estude o conteúdo dos campos recorrendo as técnicas lecionadas em aula
head(wine)
names(wine) <- tolower(names(wine))
wine$class <- as.factor(wine$class)

cat("Número de valores em falta por variável:\n")
print(colSums(is.na(wine)))

wine_limpo <- na.omit(wine)
summary(wine_limpo)

# 3. Retifique, limpe e modifique as colunas que justifique
wine_ordenado <- wine_limpo[order(wine_limpo$alcohol), ]

dados_numericos <- wine_ordenado[sapply(wine_ordenado, is.numeric)]
print("Matriz de correlação")
matriz_cor <- cor(dados_numericos)
print(round(as.data.frame(matriz_cor), 3))


wine_ordenado$phenolstotal <- NULL 


# A variável PhenolsTotal apresenta correlação muito forte com Flavanoids.
# Para evitar redundância de informação, reduzir multicolinearidade e simplificar os modelos de classificação, optou-se por remover PhenolsTotal, mantendo Flavanoids, que demonstra maior capacidade de separação entre as classes.

# 4. Levante no mínimo 2 questões do tipo BI, fundamente a pertinência das mesmas em relatório
# a. Responda as questões levantadas interpretando em relatório os resultados

# Quais são os principais compostos químicos que diferenciam os cultivares de vinho?

# A identificação dos compostos químicos que melhor diferenciam os cultivares é essencial para 
# compreender as características enológicas de cada vinho. 
# Esta análise permite destacar os atributos mais discriminativos e fornecer base sólida para modelação preditiva.
modelo_import <- rpart(class ~ ., data = wine_ordenado, method = "class")

importancia <- modelo_import$variable.importance
print("--- Importância das Variáveis ---")
print(importancia)

top_features <- names(sort(importancia, decreasing = TRUE))[1:4]
print(top_features)

# Gráfico da importância
par(mar = c(10, 4, 4, 2))
barplot(importancia,
        las = 2,
        cex.names = 0.8,
        main = "Importância das Variáveis (rpart)",
        ylab = "Importância",
        col = "lightgray",
        border = NA)


# A análise da importância das variáveis através do modelo rpart revelou que Flavanoids, OD280/OD315 e Proline são os atributos mais relevantes para distinguir as três classes de vinho.
# Flavanoids aparece como a variável principal, refletindo diferenças químicas estruturais entre os cultivares.
# O índice OD280/OD315, associado a fenóis totais, contribui fortemente para a discriminação devido à sua relação com características sensoriais como cor e qualidade.
# Proline, por sua vez, apresenta grande variação entre classes, tornando-se um importante marcador enológico.

# Como variam estes compostos químicos entre as três classes?

# Após identificar os compostos mais relevantes, é importante avaliar como estes variam entre as três classes. 
# Esta análise evidencia diferenças práticas entre os cultivares, 
# reforçando a interpretação dos resultados e permitindo caracterizar cada classe de forma mais clara.
# Boxplots das principais variáveis

# Estatísticas por classe

variaveis_bi <- c("flavanoids", "proline", "od280.od315", "alcohol")

estatisticas <- aggregate(
  wine_ordenado[, variaveis_bi],
  by = list(Classe = wine_ordenado$class),
  FUN = function(x) c(
    Min = min(x),
    Max = max(x),
    Media = mean(x),
    Mediana = median(x)
  )
)

estatisticas <- do.call(data.frame, estatisticas)
print(estatisticas)


boxplot(flavanoids ~ class, data = wine_ordenado,
        main = "Flavanoids por Classe",
        xlab = "Classe", ylab = "Flavanoids")

boxplot(od280.od315 ~ class, data = wine_ordenado,
        main = "OD280/OD315 por Classe",
        xlab = "Classe", ylab = "OD280/OD315")

boxplot(proline ~ class, data = wine_ordenado,
        main = "Proline por Classe",
        xlab = "Classe", ylab = "Proline")

boxplot(alcohol ~ class, data = wine_ordenado,
        main = "Alcohol por Classe",
        xlab = "Classe", ylab = "Alcohol")

# 4. Clusters

# Método do cotovelo
vars <- wine_ordenado[, c("flavanoids", "proline", "od280.od315", "alcohol")]

wss <- c()
for (k in 1:10) {
  km <- kmeans(vars, centers = k, nstart = 25)
  wss[k] <- km$tot.withinss
}

plot(1:10, wss, type = "b",
     xlab = "Número de Clusters (k)",
     ylab = "WSS (Within-Cluster Sum of Squares)",
     main = "Método do Cotovelo")

# k-means com k = 3
set.seed(123)
km <- kmeans(vars, centers = 3)

# adicionar cluster ao dataset ordenado
wine_ordenado$cluster <- as.factor(km$cluster)

#Estatística dos clusters
resumo_clusters <- aggregate(
  cbind(flavanoids, proline, od280.od315, alcohol) ~ cluster,
  data = wine_ordenado,
  FUN = function(x) c(
    Min = min(x),
    Max = max(x),
    Media = mean(x),
    Mediana = median(x)
  )
)

print("RESUMO DOS CLUSTERS")
print(resumo_clusters)

#Mudar nome dos clusters

levels(wine_ordenado$cluster) <- c(
  "Perfil Intermédio",
  "Perfil Químico Mais Leve",
  "Perfil Químico Mais Intenso"
)


# gráfico cluster 2D
cluster_grafico <- ggplot(wine_ordenado, aes(x = flavanoids,
                                             y = proline,
                                             color = cluster,
                                             size = od280.od315)) +
  geom_point(alpha = 0.8) +
  scale_color_manual(values = c("#1B9E77", "#D95F02", "#7570B3")) +
  labs(
    title = "Clusters (k=3) usando Flavanoids, Proline e OD280/OD315",
    x = "Flavanoids",
    y = "Proline",
    color = "Cluster",
    size = "OD280/OD315"
  ) +
  theme_minimal()

print(cluster_grafico)

#Gráfico 3D com as variáveis de maior importancia
grafico_3d <- plot_ly(wine_ordenado,
        x = ~flavanoids,
        y = ~proline,
        z = ~alcohol,
        color = ~cluster,
        size = ~od280.od315,
        type = "scatter3d",
        mode = "markers") %>%
  layout(title = "3D: Flavanoids, Proline e Alcohol (size = OD280/OD315)")

print(grafico_3d)



# 5. Questões de BA 

# 1. Quão bem o modelo de classificação consegue prever o cultivar do vinho?

#Árvore de decisão
# O modelo escolhido foi a Árvore de Decisão devido à sua elevada interpretabilidade, 
# facilidade de visualização e capacidade de evidenciar as variáveis mais discriminativas entre as classes. 
# Além disso, o dataset Wine apresenta separações naturais nas variáveis químicas,
# o que torna a árvore um modelo adequado, simples e eficaz para classificação.

selected <- wine_ordenado[, c(top_features, "class")]

set.seed(123)
dados_baralhado <- selected[sample(nrow(selected)), ]

div <- (round(nrow(dados_baralhado) / 3)) * 2

trainx <- dados_baralhado[1:div, 1:4]
trainy <- dados_baralhado[1:div, 5]

testx  <- dados_baralhado[(div+1):nrow(dados_baralhado), 1:4]
testy  <- dados_baralhado[(div+1):nrow(dados_baralhado), 5]


# Árvore de decisão 
arvore <- C5.0(trainx, trainy)
plot(arvore)

pred <- predict(arvore, testx)

resultado <- cbind(testx, Predito = pred, Real = testy)
print(resultado)

# ROC e AUC
roc_a <- roc(as.numeric(testy), as.numeric(pred))
plot(roc_a, main = "Curva ROC - Modelo C5.0", lwd = 3)

auc_value <- auc(roc_a)
print(auc_value)

# 2.	Quais variáveis contribuem mais para a previsão correta da classe?
# Random Forest

# O Random Forest foi escolhido para responder esta questão por ser um modelo robusto,
# que combina várias árvores de decisão, reduzindo o impacto de ruído e variações aleatórias nos dados.
set.seed(123)
dados_baralhado <- selected[sample(nrow(selected)), ]

div <- round(nrow(dados_baralhado) * 0.7)

train_rf <- dados_baralhado[1:div, ]
test_rf  <- dados_baralhado[(div + 1):nrow(dados_baralhado), ]

modelo_rf <- randomForest(
  class ~ .,
  data = train_rf,
  ntree = 100,
  mtry = 2,
  importance = TRUE
)

cat("Random Forest - MATRIZ DE TREINO (OOB)\n")
print(modelo_rf$confusion)
cat("\nErro OOB:", round(modelo_rf$err.rate[100, "OOB"] * 100, 2), "%\n")

cat("Random Forest - MATRIZ DE TESTE\n")
pred_rf <- predict(modelo_rf, test_rf)

mat_teste <- table(Real = test_rf$class, Previsto = pred_rf)
print(mat_teste)

cat("\nTotal de observações no teste:", nrow(test_rf), "\n")

num_erros <- sum(test_rf$class != pred_rf)
cat("Número de erros:", num_erros, "\n")

AUC_rf <- mean(pred_rf == test_rf$class)
cat("Acurácia do Random Forest no conjunto de teste:", AUC_rf, "\n")

importance(modelo_rf)
varImpPlot(modelo_rf)

# 6. Elabore uma reflecção final sobre a viabilidade dos resultados obtidos 

# Ambos os modelos de classificação apresentaram desempenho muito elevado na previsão das classes de vinho, embora com características diferentes em termos de interpretabilidade e robustez.
# 
# A Árvore de Decisão destacou-se pela sua elevada interpretabilidade. 
# A estrutura em forma de árvore permite visualizar diretamente as regras utilizadas na classificação,
# como divisões baseadas em Flavanoids, Proline ou Alcohol. Além disso, o modelo alcançou AUC = 0,93.
# A AUC (Area Under the Curve) mede a capacidade do modelo em distinguir corretamente as classes.
# Um valor de 0,93 significa que a árvore conseguiu separar 93% dos vinhos sem qualquer erro,
# demonstrando uma capacidade discriminativa perfeita para este conjunto de dados.
# 
# Já o modelo Random Forest apresentou um desempenho também muito elevado,
# com acurácia aproximada de 92% no conjunto de teste (49 acertos em 53 vinhos).
# A acurácia representa a proporção de previsões corretas feitas pelo modelo.

