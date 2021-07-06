import { NativeModules } from 'react-native';

const RCTIAP = NativeModules.RCTIAP;

const IAP = {

    /**
     * 获取没有验证订单
     * @returns {*}
     */
    iapUnverifyOrdersArray:function(){
        return RCTIAP.iapUnverifyOrdersArray;
    },
    /**
     * 获取所有在售商品
     */
    purchaseAllProducts:function (productIdentifiers) {
        return new Promise((resolve,reject)=>{
            RCTIAP.loadProducts(productIdentifiers,(er,re)=>{
                if (er){
                    reject(er)
                } else {
                    resolve(re)
                }
            })
        })
    },
    /**
     * 获取某个商品(此方法需要先获取purchaseAllProducts)
     */
    purchaseProduct:function(productIdentifier){
        return new Promise((resolve,reject)=>{
            RCTIAP.purchaseProduct(productIdentifier,(er,re)=>{
                if (er) {
                    reject(er);
                }else{
                    resolve(re);
                }
            })
        });
    },

    /**
     * 发起购买
     */
    purchaseProduct:function (productIdentifier) {
        return new Promise((resolve,reject)=>{
            RCTIAP.purchaseProduct(productIdentifier,(er,re)=>{
                if (er){
                    reject(er);
                } else {
                    resolve(re);
                }
            })
        })
    },

    /**
     * 重新添加购买流程的监听（此方法是为了针对支付构成中，出现意外导致丢单，再次发起获取监听
     * @returns {Promise<any> | Promise}
     */
    addTransactionObserverWithCallback:function(){
        return new Promise((resolve,reject)=>{
            RCTIAP.addTransactionObserverWithCallback((er,re)=>{
                if (er){
                    reject(er)
                } else{
                    resolve(re);
                }
            })
        })
    },
    /**
     * 重新恢复购买
     * @returns {Promise<any> | Promise}
     */
    restorePurchases:function(){
        return new Promise((resolve,reject)=>{
            RCTIAP.restorePurchases((er,re)=>{
                if (er) {
                    reject(er)
                }else {
                    resolve(re)
                }
            })
        })
    },
    /**
     * 验证成功后，删除购买凭证
     * @param purchase
     */
    removePurchase:function (purchase) {
        RCTIAP.removePurchase(purchase)
    }



}


export default IAP;
