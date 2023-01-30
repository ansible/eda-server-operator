/*
Copyright 2023.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controllers

import (
	"context"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	automationedav1beta1 "github.com/ansible/aap-eda-operator/api/v1beta1"
)

const (
	// typeAvailableEda represents the status of the StatefulSet reconciliation
	typeAvailableEda = "Available"
	// typeDegradedEda represents the status used when the custom resource is deleted and the finalizer operations are must to occur.
	typeDegradedEda = "Degraded"
)

// EdaReconciler reconciles a Eda object
type EdaReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

//+kubebuilder:rbac:groups=automationeda.ansible.com,resources=edas,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=automationeda.ansible.com,resources=edas/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=automationeda.ansible.com,resources=edas/finalizers,verbs=update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the Eda object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.13.0/pkg/reconcile
func (r *EdaReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := log.FromContext(ctx)

	eda := &automationedav1beta1.Eda{}
	err := r.Get(ctx, req.NamespacedName, eda)
	if err != nil {
		if apierrors.IsNotFound(err) {
			log.Info("Eda resource not found. Ignoring since object must be deleted")
			return ctrl.Result{}, nil
		}

		log.Error(err, "Failed to get Eda")
		return ctrl.Result{}, err
	}

	reconcileResult, err := r.reconcilePostgres(ctx, eda)

	return reconcileResult, err
}

// SetupWithManager sets up the controller with the Manager.
func (r *EdaReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&automationedav1beta1.Eda{}).
		Owns(&corev1.Service{}).
		Owns(&appsv1.StatefulSet{}).
		Complete(r)
}
