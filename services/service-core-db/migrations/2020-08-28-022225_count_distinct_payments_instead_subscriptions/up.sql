-- Your SQL goes here
CREATE OR REPLACE VIEW "payment_service_api"."subscriptions_per_month" AS 
 SELECT s.project_id,
    count(DISTINCT cp.id) AS total_subscriptions,
    COALESCE(sum(((cp.data ->> 'amount'::text))::numeric), (0)::numeric) AS total_amount,
    count(DISTINCT s.id) FILTER (WHERE (first_payment.id = cp.id)) AS new_subscriptions,
    COALESCE(sum(((cp.data ->> 'amount'::text))::numeric) FILTER (WHERE (first_payment.id = cp.id)), (0)::numeric) AS new_amount,
    p.external_id AS project_external_id,
    (cp.data ->> 'payment_method'::text) AS payment_method,
    (date_trunc('month'::text, payment_service.paid_transition_at(cp.*)))::date AS month
   FROM (((payment_service.catalog_payments cp
     JOIN payment_service.subscriptions s ON ((cp.subscription_id = s.id)))
     LEFT JOIN LATERAL ( SELECT get_first_paid_payment.id,
            get_first_paid_payment.platform_id,
            get_first_paid_payment.project_id,
            get_first_paid_payment.user_id,
            get_first_paid_payment.subscription_id,
            get_first_paid_payment.reward_id,
            get_first_paid_payment.data,
            get_first_paid_payment.gateway,
            get_first_paid_payment.gateway_cached_data,
            get_first_paid_payment.created_at,
            get_first_paid_payment.updated_at,
            get_first_paid_payment.common_contract_data,
            get_first_paid_payment.gateway_general_data,
            get_first_paid_payment.status,
            get_first_paid_payment.external_id,
            get_first_paid_payment.error_retry_at,
            get_first_paid_payment.contribution_id
           FROM payment_service.get_first_paid_payment(s.id) get_first_paid_payment(id, platform_id, project_id, user_id, subscription_id, reward_id, data, gateway, gateway_cached_data, created_at, updated_at, common_contract_data, gateway_general_data, status, external_id, error_retry_at, contribution_id)) first_payment ON (true))
     JOIN project_service.projects p ON ((p.id = s.project_id)))
  WHERE ((cp.status = 'paid'::payment_service.payment_status) AND ((s.status <> 'deleted'::payment_service.subscription_status) AND (s.platform_id = core.current_platform_id()) AND (core.is_owner_or_admin(s.user_id) OR core.is_owner_or_admin(p.user_id))))
  GROUP BY ((date_trunc('month'::text, payment_service.paid_transition_at(cp.*)))::date), s.project_id, p.external_id, (cp.data ->> 'payment_method'::text);
