####load libraries
library(tidyverse)
library(dplyr)
library(survival)
library(survminer)
library(ggpubr)
library(ggplot2)
library(PredictABEL)
library(pROC)

####impute
impute<-function(x){
  y<-x
  y[is.na(x)]<-sample(x[!is.na(x)], size=sum(is.na(x)), replace=T)
  return(y)
}

####import training and test set data files
##file format
#excel or csv
#columns: dcnn prediction, baseline ecog, treatment category, response to treatment, pfs, time to pfs
#file 1 = training dataset; file 2 = test dataset
training
test

####reformat variables
##training
set.seed(1998)
training$baseline_ecog.i<-as.numeric(as.character(training$baseline_ecog))
training$baseline_ecog.i<-impute(training$baseline_ecog.i)

####dcnn model
##response_code should is a binary (0=response; 1=no response)
##dcnn_prediction is generated by the neural network classifier
model1<-glm(response_code~dcnn_prediction,data=training,family="binomial")

####multivaribale model
model2<-glm(response_code~dcnn_prediction+baseline_ecog.i+treatment_category,data=training,family="binomial")

#obtain predicted risks
training_predRisk1 <- predRisk(model1)
training_predRisk2 <- predRisk(model2)

####create new columns
training$dcnn = training_predRisk1
training$logistic = training_predRisk2

#####set outcome
trainingOutcome <- which(names(training)=="response_code")

#specify labels of the ROC curve
labels <- c("DCNN","DCNN + Clinical Data" )

#produce ROC curve
plotROC(data=training, cOutcome=trainingOutcome,
        predrisk=cbind(training_predRisk1,training_predRisk2), labels=labels)

####validation on test dataset
####reformat variables
set.seed(1998)
test$baseline_ecog.i<-as.numeric(as.character(test$baseline_ecog))
test$baseline_ecog.i<-impute(test$baseline_ecog.i)

####
test_predRisk1 <- predict(model1, newdata = test, type = 'response')
test_predRisk2 <- predict(model2, newdata = test, type = 'response')

####create new columns
test$dcnn = test_predRisk1
test$logistic = test_predRisk2

####set outcome
testOutcome <- which(names(test)=="response_code")

####plot roc
plotROC(data=test, cOutcome=testOutcome,
        predrisk=cbind(test_predRisk1,test_predRisk2), labels=labels)

####use the optimal cut point from the training roc curve to stratify patients into low versus high risk for progression
##identify optimal cut point
training_roc <- roc(training$response_code, training$logistic)
coords(training_roc, x="best", input="threshold", best.method="closest.topleft")
CUT=0.7395212 #spec: 0.8372093 #sen: 0.6410256

####generate km curves
test$risk = ifelse(test$logistic>=CUT, 'High', 'Low')
test_fit <- survfit(Surv(time_to_pfs, pfs)~risk, data=test)
km_test <-ggsurvplot(test_fit, data = test,
                  title="DCNN + Clinical Data",
                  pval = T, pval.coord = c(0,0.03),
                  risk.table = F,
                  legend.labs = c("High Risk", "Low Risk"),
                  conf.int = F,
                  xlim=c(0,500),
                  xlab = c('Time (Days)'),
                  ylab = c('PFS Probability'),
                  font.legend = list(size=20),
                  font.x=c(20), 
                  font.y=c(20), 
                  font.tickslab=c(15),
                  pval.size = 6,
                  font.title=c(25))
km_test